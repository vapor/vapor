import Bits
import Foundation
import Async
import TCP
import Dispatch

/// A connectio to a MySQL database servers
public final class Connection {
    /// The TCP socket it's connected on
    let socket: Socket
    
    /// The queue on which the TCP socket is reading
    let queue: DispatchQueue
    
    /// The internal buffer in which incoming data is stored
    let buffer: MutableByteBuffer
    
    /// Parses the incoming buffers into packets
    let parser: PacketParser
    
    /// The state of the server's handshake
    var handshake: Handshake?
    
    /// A dispatch source that reads on the provided queue
    var source: DispatchSourceRead
    
    /// The username to authenticate with
    let username: String
    
    /// The password to authenticate with
    let password: String?
    
    /// The database to select
    let database: String?
    
    /// A future promise
    var authenticated: Promise<Void>
    
    /// The client's capabilities
    var capabilities: Capabilities {
        var base: Capabilities = [
            .protocol41, .longFlag, .secureConnection
        ]
        
        if database != nil {
            base.update(with: .connectWithDB)
        }
        
        return base
    }
    
    /// If `true`, both parties support MySQL's v4.1 protocol
    var mysql41: Bool {
        // client && server 4.1 support
        return handshake?.isGreaterThan4 == true && self.capabilities.contains(.protocol41) && handshake?.capabilities.contains(.protocol41) == true
    }
    
    /// Creates a new connection and completes the handshake
    public static func makeConnection(hostname: String, port: UInt16 = 3306, user: String, password: String?, database: String?, queue: DispatchQueue) throws -> Future<Connection> {
        let connection = try Connection(hostname: hostname, port: port, user: user, password: password, database: database, queue: queue)
        
        return connection.authenticated.future.map { _ in
            return connection
        }
    }
    
    /// Creates a new connection
    ///
    /// Doesn't finish the handshake synchronously
    init(hostname: String, port: UInt16 = 3306, user: String, password: String?, database: String?, queue: DispatchQueue) throws {
        let socket = try Socket()
        
        let bufferSize = Int(UInt16.max)
        
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        let buffer = MutableByteBuffer(start: pointer, count: bufferSize)
        
        try socket.connect(hostname: hostname, port: port)
        
        let parser = PacketParser()

        let source = DispatchSource.makeReadSource(
            fileDescriptor: socket.descriptor,
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
        
        self.authenticated = Promise<Void>()
        
        self.parser.drain(self.handlePacket).catch { error in
            // FIXME: @joannis
            fatalError("\(error)")
        }
    }
    
    /// Closes the connection
    func close() {
        self.socket.close()
    }
    
    /// Sets the proided handler to capture packets
    ///
    /// - throws: The connection is reserved
    internal func receivePackets(into handler: @escaping ((Packet) -> ())) {
        self.parser.outputStream = handler
    }
    
    /// Handles the incoming packet with the default handler
    ///
    /// Handles the packet for the handshake
    internal func handlePacket(_ packet: Packet) {
        guard self.handshake != nil else {
            self.doHandshake(for: packet)
            return
        }
        
        guard authenticated.future.isCompleted else {
            finishAuthentication(for: packet, completing: authenticated)
            return
        }
        
        // We're expecting nothing
    }
    
    /// Writes a packet's payload data to the socket
    func write(packetFor data: Data, startingAt start: UInt8 = 0) throws {
        // Creates a pointer to call the other handler
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        
        defer {
            // deallocate the pointer after writing is completed
            pointer.deallocate(capacity: data.count)
        }
        
        data.copyBytes(to: pointer, count: data.count)
        
        let buffer = ByteBuffer(start: pointer, count: data.count)
        
        try write(packetFor: buffer)
    }
    
    /// Writes a packet's payload buffer to the socket
    func write(packetFor data: ByteBuffer, startingAt start: UInt8 = 0) throws {
        var offset = 0
        
        guard let input = data.baseAddress else {
            throw Error(.invalidPacket)
        }
        
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: Packet.maxPayloadSize &+ 4)
        
        defer {
            pointer.deallocate(capacity: Packet.maxPayloadSize &+ 4)
        }
        
        // Starts the packet number at the starting number
        // The handshake starts at 1, instead of 0
        var packetNumber: UInt8 = start
        
        // Splits the paylad into packets
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
