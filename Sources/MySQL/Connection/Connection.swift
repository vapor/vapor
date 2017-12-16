import Bits
import Foundation
import Async
import TCP
import TLS
import Dispatch

/// Contains settings that MySQL uses to upgrade
public struct MySQLSSLConfig {
    var upgrader: SSLClientUpgrader
    var settings: SSLClientSettings
    
    public init(upgrader: SSLClientUpgrader, settings: SSLClientSettings) {
        self.upgrader = upgrader
        self.settings = settings
    }
}

/// A connectio to a MySQL database servers
public final class MySQLConnection {
    /// The socket it's connected on
    var socket: TCPClient
    
    /// The queue on which the TCP socket is reading
    let queue: DispatchQueue
    
    /// The internal buffer in which incoming data is stored
    let buffer: MutableByteBuffer
    
    /// Parses the incoming buffers into packets
    let parser: PacketParser
    
    /// The state of the server's handshake
    var handshake: Handshake?
    
    /// The username to authenticate with
    let username: String
    
    /// The password to authenticate with
    let password: String?
    
    /// The database to select
    let database: String
    
    /// A future promise
    var authenticated: Promise<Void>
    
    // A buffer that stores all packets before writing
    let writeBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Packet.maxPayloadSize &+ 4)
    
    let readBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(UInt16.max))
    
    /// The inserted ID from the last successful query
    public var lastInsertID: UInt64?
    
    /// Amount of affected rows in the last successful query
    public var affectedRows: UInt64?
    
    /// This container is used for fabricating TLS helpers
    var eventLoop: EventLoop
    
    /// Indicates if this socket should be upgraded to SSL and how to upgrade
    var ssl: MySQLSSLConfig?
    
    /// Indicates that the SSL handshake has been sent
    var sslSettingsSent = false

    /// Basic stream to easily implement async stream.
    var packetStream: BasicStream<Packet>
    
    /// The write function for the socket
    var socketWrite: ((ByteBuffer) throws -> ())
    
    /// The client's capabilities
    var capabilities: Capabilities {
        let base: Capabilities = [
            .longPassword, .protocol41, .longFlag, .secureConnection, .connectWithDB
        ]
        
        return base
    }
    
    /// If `true`, both parties support MySQL's v4.1 protocol
    var mysql41: Bool {
        // client && server 4.1 support
        return handshake?.isGreaterThan4 == true && self.capabilities.contains(.protocol41) && handshake?.capabilities.contains(.protocol41) == true
    }
    
    /// Creates a new connection
    ///
    /// Doesn't finish the handshake synchronously
    init(
        hostname: String,
        port: UInt16 = 3306,
        ssl: MySQLSSLConfig? = nil,
        user: String,
        password: String?,
        database: String,
        on eventLoop: EventLoop
    ) throws {
        let buffer = MutableByteBuffer(start: readBuffer, count: Int(UInt16.max))
        
        let parser = PacketParser()
        self.authenticated = Promise<Void>()
        
        let socket = try TCPClient(on: eventLoop)
        socket.stream(to: parser)
        
        self.socket = socket
        self.socketWrite = socket.onInput
        self.ssl = ssl
        
        self.parser = parser
        self.queue = eventLoop.queue
        self.buffer = buffer
        self.username = user
        self.password = password
        self.database = database
        self.packetStream = .init()
        self.eventLoop = eventLoop
        
        try socket.connect(hostname: hostname, port: port).catch(authenticated.fail)
        
        self.parser.drain(onInput: self.handlePacket).catch { error in
            /// close the packet stream
            self.authenticated.fail(error)
            self.packetStream.onError(error)
            self.close()
        }
    }
    
    /// Handles the incoming packet with the default handler
    ///
    /// Handles the packet for the handshake
    internal func handlePacket(_ packet: Packet) {
        if authenticated.future.isCompleted {
            return
        }
        
        if let ssl = ssl {
            guard sslSettingsSent else {
                do {
                    try self.upgradeSSL(for: packet, using: ssl)
                } catch {
                    self.authenticated.fail(error)
                    self.close()
                }
                
                return
            }
        }
        
        guard self.handshake != nil else {
            self.doHandshake(for: packet)
            return
        }
        
        finishAuthentication(for: packet, completing: authenticated)
    }
    
    func upgradeSSL(for packet: Packet, using config: MySQLSSLConfig) throws {
        let handshake = try packet.parseHandshake()
        self.handshake = handshake
        
        var data = Data(repeating: 0, count: 32)
        
        data.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
            let combinedCapabilities = self.capabilities.rawValue & handshake.capabilities.rawValue
            
            memcpy(pointer, [
                UInt8((combinedCapabilities) & 0xff),
                UInt8((combinedCapabilities >> 1) & 0xff),
                UInt8((combinedCapabilities >> 2) & 0xff),
                UInt8((combinedCapabilities >> 3) & 0xff),
            ], 4)
            
            pointer.advanced(by: 8).pointee = handshake.defaultCollation
            
            // the rest is reserved
        }
        
        try data.withByteBuffer { buffer in
            try self.write(packetFor: buffer)
        }
        
        try config.upgrader.upgrade(
            socket: self.socket.socket,
            settings: config.settings,
            eventLoop: self.socket.eventLoop
        ).map { client in
            client.stream(to: self.parser)
            self.socketWrite = client.onInput
            
            try self.sendHandshake()
        }.catch(self.authenticated.fail)
    }
    
    /// Writes a packet's payload data to the socket
    func write(packetFor data: Data, startingAt start: UInt8 = 0) throws {
        try data.withUnsafeBytes { (pointer: BytesPointer) in
            let buffer = ByteBuffer(start: pointer, count: data.count)
            
            try write(packetFor: buffer)
        }
    }
    
    /// Writes a packet's payload buffer to the socket
    func write(packetFor data: ByteBuffer, startingAt start: UInt8 = 0) throws {
        var offset = 0
        
        guard let input = data.baseAddress else {
            throw MySQLError(.invalidPacket)
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
            
            memcpy(self.writeBuffer, packetSizeBytes, 3)
            self.writeBuffer[3] = packetNumber
            memcpy(self.writeBuffer.advanced(by: 4), input.advanced(by: offset), dataSize)
            
            let buffer = ByteBuffer(start: self.writeBuffer, count: dataSize &+ 4)
            _ = try self.socketWrite(buffer)
        }
        
        return
    }

    deinit {
        writeBuffer.deinitialize(count: Packet.maxPayloadSize &+ 4)
        writeBuffer.deallocate(capacity: Packet.maxPayloadSize &+ 4)

        readBuffer.deinitialize(count: Int(UInt16.max))
        readBuffer.deallocate(capacity: Int(UInt16.max))

        self.socket.close()
        self.packetStream.close()
    }
    
    /// Closes the connection
    public func close() {
        // Write `close`
        _ = try? self.write(packetFor: Data([0x01]))
        self.socket.close()
        self.packetStream.close()
    }
}

/// MARK: Static

extension MySQLConnection {
    /// Creates a new connection and completes the handshake
    public static func makeConnection(
        hostname: String,
        port: UInt16 = 3306,
        ssl: MySQLSSLConfig? = nil,
        user: String,
        password: String?,
        database: String,
        on eventLoop: EventLoop
    ) -> Future<MySQLConnection> {
        return then {
            let connection = try MySQLConnection(
                hostname: hostname,
                port: port,
                ssl: ssl,
                user: user,
                password: password,
                database: database,
                on: eventLoop
            )

            return connection.authenticated.future.map { _ in
                return connection
            }
        }
    }
}
