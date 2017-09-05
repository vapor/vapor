import Bits
import Async
import Foundation
import TCP
import Dispatch

struct Capabilities : OptionSet, ExpressibleByIntegerLiteral {
    var rawValue: UInt32
    
    static let protocol41: Capabilities = 0x0200
    static let longFlag: Capabilities = 0x0004
    static let connectWithDB: Capabilities = 0x0008
    static let secureConnection: Capabilities = 0x8000
    
    init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    init(integerLiteral value: UInt32) {
        self.rawValue = value
    }
}

protocol Table : Decodable {}

final class Connection {
    let socket: Socket
    let queue: DispatchQueue
    let buffer: MutableByteBuffer
    let parser: PacketParser
    var resultsBuilder: Table?
    var handshake: Handshake?
    var source: DispatchSourceRead
    let username: String
    let password: String?
    let database: String?
    
    var currentQuery: Promise<Bool>?
    
    var currentQueryFuture: Future<Bool>? {
        return currentQuery?.future
    }
    
    var authenticated: Bool?
    
    var capabilities: Capabilities {
        var base: Capabilities = [
            .protocol41, .longFlag, .secureConnection
        ]
        
        if database != nil {
            base.update(with: .connectWithDB)
        }
        
        return base
    }
    
    var mysql41: Bool {
        // client && server 4.1 support
        return handshake?.isGreaterThan4 == true && self.capabilities.contains(.protocol41) && handshake?.capabilities.contains(.protocol41) == true
    }
    
    var initialized: Bool {
        return self.handshake != nil
    }
    
    init(hostname: String, port: UInt16 = 3306, user: String, password: String?, database: String?, queue: DispatchQueue) throws {
        let socket = try Socket()
        
        let bufferSize = Int(UInt16.max)
        
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        let buffer = MutableByteBuffer(start: pointer, count: bufferSize)
        
        try socket.connect(hostname: hostname, port: port)
        
        let parser = PacketParser()

        let source = DispatchSource.makeReadSource(
            fileDescriptor: socket.descriptor.raw,
            queue: queue
        )

        source.setEventHandler {
            do {
                let usedBufferSize = try socket.read(max: bufferSize, into: buffer)
                
                // Reuse existing pointer to data
                let newBuffer = MutableByteBuffer(start: pointer, count: usedBufferSize)
                
                parser.inputStream(newBuffer)
            } catch {
                socket.close()
            }
        }
        source.resume()
        self.source = source
        
        self.parser = parser
        self.socket = socket
        self.queue = queue
        self.buffer = buffer
        self.source = source
        self.username = user
        self.password = password
        self.database = database
        self.parser.drain(self.handlePacket)
        self.currentQuery = Promise<Bool>()
    }
    
    func close() {
        self.socket.close()
    }
    
    func onPackets(_ handler: @escaping ((Packet) -> ())) -> Promise<Bool> {
        _ = try? self.currentQueryFuture?.sync()
        let promise = Promise<Bool>()
        
        self.currentQuery = promise
        self.parser.outputStream = handler
        
        promise.future.then { _ in
            self.parser.drain(self.handlePacket)
        }.catch { error in
            promise.fail(error)
        }
        
        return promise
    }
    
    func handlePacket(_ packet: Packet) {
        guard self.handshake != nil else {
            self.doHandshake(for: packet)
            return
        }
        
        guard let authenticated = authenticated else {
            finishAuthentication(for: packet)
            return
        }
        
        guard authenticated else {
            self.socket.close()
            return
        }
    }
    
    func write(packetFor data: Data, startingAt start: UInt8 = 0) throws {
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        
        defer {
            pointer.deallocate(capacity: data.count)
        }
        
        data.copyBytes(to: pointer, count: data.count)
        
        let buffer = ByteBuffer(start: pointer, count: data.count)
        
        try write(packetFor: buffer)
    }
    
    func write(packetFor data: ByteBuffer, startingAt start: UInt8 = 0) throws {
        var offset = 0
        
        guard let input = data.baseAddress else {
            throw MySQLError.invalidPacket
        }
        
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: Packet.maxPayloadSize &+ 4)
        
        defer {
            pointer.deallocate(capacity: Packet.maxPayloadSize &+ 4)
        }
        
        var packetNumber: UInt8 = start
        
        while offset < data.count {
            defer {
                packetNumber = packetNumber &+ 1
            }
            
            let dataSize = min(Packet.maxPayloadSize, data.count &- offset)
            let packetSize = UInt32(dataSize)
            
            let packetSizeBytes = [
                UInt8((packetSize) & 0xff),
                UInt8((packetSize >> 8) & 0xff),
                UInt8((packetSize >> 16) & 0xff),
            ]
            
            defer {
                offset = offset + dataSize
            }
            
            memcpy(pointer, packetSizeBytes, 3)
            pointer[3] = packetNumber
            memcpy(pointer.advanced(by: 4), input.advanced(by: offset), dataSize)
            
            let buffer = ByteBuffer(start: pointer, count: dataSize &+ 4)
            _ = try self.socket.write(max: dataSize &+ 4, from: buffer)
        }
        
        return
    }
}
