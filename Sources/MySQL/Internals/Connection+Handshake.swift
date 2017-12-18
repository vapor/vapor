import Async
import TCP
import Bits
import Crypto
import JunkDrawer
import Foundation

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
        let connector = MySQLConnector(
            hostname: hostname,
            port: port,
            user: user,
            password: password,
            database: database,
            ssl: ssl,
            on: eventLoop
        )
        
        return connector.connect()
    }
}

/// This library's capabilities
var capabilities: Capabilities {
    let base: Capabilities = [
        .longPassword, .protocol41, .longFlag, .secureConnection, .connectWithDB
    ]
    
    return base
}

extension Handshake {
    /// If `true`, both parties support MySQL's v4.1 protocol
    var mysql41: Bool {
        // client && server 4.1 support
        return self.isGreaterThan4 == true && capabilities.contains(.protocol41) && self.capabilities.contains(.protocol41) == true
    }
}

fileprivate final class MySQLConnector {
    enum ConnectionState {
        case start, sentHandshake, sentSSL
    }
    
    let hostname: String
    let port: UInt16
    let user: String
    let password: String?
    let database: String
    let ssl: MySQLSSLConfig?
    let eventLoop: EventLoop
    
    let serializer = MySQLPacketSerializer()
    
    var state: ConnectionState
    var handshake: Handshake?
    
    init(
        hostname: String,
        port: UInt16,
        user: String,
        password: String?,
        database: String,
        ssl: MySQLSSLConfig?,
        on eventLoop: EventLoop
    ) {
        self.hostname = hostname
        self.port = port
        self.state = .start
        self.user = user
        self.password = password
        self.database = database
        self.ssl = ssl
        self.eventLoop = eventLoop
    }
    
    func connect() -> Future<MySQLConnection> {
        do {
            let promise = Promise<MySQLConnection>()
            let socket = try TCPSocket()
            let client = try TCPClient(socket: socket)
            
            try client.connect(hostname: hostname, port: port)
            
            let source = socket.source(on: eventLoop)
            let parser = source.stream(to: MySQLPacketParser())

            let sink = socket.sink(on: eventLoop)
            self.serializer.output(to: sink)
            
            func complete() throws {
                guard let handshake = self.handshake else {
                    throw MySQLError(.invalidHandshake)
                }
                
                let connection = MySQLConnection(
                    handshake: handshake,
                    source: .init(source),
                    sink: .init(sink)
                )
                promise.complete(connection)
            }
            
            _ = parser.drain { upstream in
                upstream.request()
            }.output { packet in
                switch self.state {
                case .start:
                    self.handshake = try self.doHandshake(for: packet)
                case .sentHandshake:
                    if let ssl = self.ssl {
                        // FIXME:
                        fatalError("SSL not supported yet \(ssl)")
                    } else {
                        try self.finishAuthentication(for: packet)
                        try complete()
                    }
                case .sentSSL:
                    try self.finishAuthentication(for: packet)
                    try complete()
                }
            }.catch(onError: promise.fail)
            
            return promise.future
        } catch {
            return Future(error: error)
        }
    }
    
    /// Respond to the server's incoming handshake
    func doHandshake(for packet: Packet) throws -> Handshake {
        let handshake = try packet.parseHandshake()
        
        try self.sendHandshake(for: handshake)
        
        return handshake
    }
    
    /// Send the handshake to the client
    func sendHandshake(for handshake: Handshake) throws {
        if handshake.isGreaterThan4 {
            var size = 32 + self.user.utf8.count + 1 + database.utf8.count + 1
            
            if let password = self.password, handshake.capabilities.contains(.secureConnection) {
                size += 21
            } else {
                size += 1
            }
            
            let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
            pointer.initialize(to: 0, count: size)
            
            defer {
                pointer.deinitialize(count: size)
                pointer.deallocate(capacity: size)
            }
            
            let username = [UInt8](self.user.utf8)
            
            let combinedCapabilities = capabilities.rawValue & handshake.capabilities.rawValue
            
            var writer = pointer
            
            memcpy(writer, [
                UInt8((combinedCapabilities) & 0xff),
                UInt8((combinedCapabilities >> 1) & 0xff),
                UInt8((combinedCapabilities >> 2) & 0xff),
                UInt8((combinedCapabilities >> 3) & 0xff),
            ], 4)
            
            writer += 4
            
            // UInt32(0) for the maximum packet length, or, undefined
            // pointer is already 0 here
            writer += 4
            
            writer.pointee = handshake.defaultCollation
            writer += 1
            
            // 23 reserved space
            writer += 23
            
            memcpy(writer, username, username.count)
            
            // 1 null terminator
            writer += username.count + 1
            
            if let password = password {
                let hash = sha1Encrypted(from: password, seed: handshake.randomSeed)
                
                // SHA1.digestSize == 20
                writer.pointee = 20
                writer += 1
                
                // SHA1 is always 20 long
                hash.withByteBuffer { buffer in
                    _ = memcpy(writer, buffer.baseAddress!, 20)
                }
                writer += 20
            } else {
                writer.pointee = 0
                writer += 1
            }
            
            memcpy(writer, database, database.utf8.count)
            writer += database.count + 1
            
            // SequenceId 1
            pointer[3] = 1
            
            let data = ByteBuffer(start: pointer, count: size)
            
            self.serializer.queue(Packet(payload: data))
        } else {
            throw MySQLError(.invalidHandshake)
        }
    }
    
    func sha1Encrypted(from password: String, seed: [UInt8]) -> Data {
        let hashedPassword = SHA1.hash(password)
        let doublePasswordHash = SHA1.hash(hashedPassword)
        var hash = SHA1.hash(seed + doublePasswordHash)
        
        for i in 0..<20 {
            hash[i] = hash[i] ^ hashedPassword[i]
        }
        
        return hash
    }
    
    /// Parse the authentication request
    func finishAuthentication(for packet: Packet) throws {
        switch packet.payload.first {
        case 0xfe:
            if packet.payload.count == 0 {
                throw MySQLError(.invalidHandshake)
            } else {
                var offset = 1
                
                while offset < packet.payload.count, packet.payload[offset] != 0x00 {
                    offset = offset &+ 1
                }
                
                guard
                    offset < packet.payload.count,
                    let password = self.password,
                    let mechanism = String(bytes: packet.payload[1..<offset], encoding: .utf8)
                else {
                    throw MySQLError(.invalidHandshake)
                }
                
                switch mechanism {
                case "mysql_native_password":
                    guard offset &+ 2 < packet.payload.count else {
                        throw MySQLError(.invalidHandshake)
                    }
                    
                    let hash = sha1Encrypted(from: password, seed: Array(packet.payload[(offset &+ 1)...]))
                    
                    serializer.queue(Packet(data: hash))
                case "mysql_clear_password":
                    serializer.queue(Packet(data: Data(password.utf8)))
                default:
                    throw MySQLError(.invalidHandshake)
                }
            }
        case 0xff:
            throw MySQLError(packet: packet)
        default:
            // auth is finished, have the parser stream to the packet stream now
            return
        }
        
        let response = try packet.parseResponse(mysql41: handshake?.mysql41 == true)
        
        switch response {
        case .error(let error):
            throw error
        default:
            return
        }
    }
}


