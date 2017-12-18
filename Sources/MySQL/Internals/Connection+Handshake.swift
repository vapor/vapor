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
        .longPassword, .protocol41, .longFlag, .connectWithDB, .secureConnection
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
                    parser: parser,
                    serializer: serializer,
                    close: socket.close
                )
                
                promise.complete(connection)
            }
            
            _ = parser.drain { upstream in
                upstream.request()
            }.output { packet in
                // https://mariadb.com/kb/en/library/1-connecting-connecting/
                switch self.state {
                case .start:
                    if let ssl = self.ssl {
                        _ = ssl
                        fatalError("Unsupported StartTLS")
                        // Do SSL upgrade
                        // self.state = .sendSSL
                    } else {
                        self.handshake = try self.doHandshake(for: packet)
                        self.state = .sentHandshake
                    }
                    
                    parser.request()
                case .sentSSL:
                    self.handshake = try self.doHandshake(for: packet)
                    self.state = .sentHandshake
                    parser.request()
                case .sentHandshake:
                    if try self.finishAuthentication(for: packet) {
                        try complete()
                    } else {
                        parser.request()
                    }
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
            var data = Data()
            
            let combinedCapabilities = capabilities.rawValue & handshake.capabilities.rawValue
            
            data.append(contentsOf: [
                UInt8((combinedCapabilities) & 0xff),
                UInt8((combinedCapabilities >> 1) & 0xff),
                UInt8((combinedCapabilities >> 2) & 0xff),
                UInt8((combinedCapabilities >> 3) & 0xff),
            ])
            
            // UInt32(0) for the maximum packet length, or, undefined
            // pointer is already 0 here
            data.append(contentsOf: [0,0,0,0])
            
            data.append(handshake.defaultCollation)
            
            // 23 reserved space
            data.append(contentsOf: [UInt8](repeating: 0, count: 23))
            
            // user + null terminator
            data.append(contentsOf: self.user.utf8)
            data.append(0)
            
            if let password = password, handshake.capabilities.contains(.secureConnection) {
                let hash = sha1Encrypted(from: password, seed: handshake.randomSeed)
                
                // SHA1.digestSize == 20
                data.append(numericCast(hash.count))
                data.append(hash)
            } else {
                data.append(0)
            }
            
            if handshake.capabilities.contains(.connectWithDB) {
                data.append(contentsOf: database.utf8)
                data.append(0)
            }
            
            let packet = Packet(data: data)
            
            // handshake starts at 1
            packet.sequenceId = 1
            
            self.serializer.queue(packet)
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
    func finishAuthentication(for packet: Packet) throws -> Bool {
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
            
            return false
        case 0xff:
            throw MySQLError(packet: packet)
        default:
            // auth is finished, have the parser stream to the packet stream now
            return true
        }
    }
}


