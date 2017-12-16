import Bits
import Foundation
import Async
import TCP
import TLS
import Dispatch

/// Contains settings that MySQL uses to upgrade
public struct MySQLSSLConfig {
    var client: TLSSocket.Type
    var settings: TLSClientSettings
    
    public init(client: TLSSocket.Type, settings: TLSClientSettings) {
        self.client = client
        self.settings = settings
    }
}

/// A connectio to a MySQL database servers
public final class MySQLConnection {
    /// The socket it's connected on
    var client: TCPClient
    
    /// The socket it's connected on
    var socket: DispatchSocket
    
    /// The eventloop to listen for socket data on
    var eventLoop: EventLoop
    
    /// Parses the incoming buffers into packets
    let parser: MySQLPacketParser
    
    /// The username to authenticate with
    let username: String
    
    /// The password to authenticate with
    let password: String?
    
    /// The database to select
    let database: String
    
    /// The state of the server's handshake
    var handshake: Handshake?
    
    /// Indicates that the SSL handshake has been sent
    var sslSettingsSent = false
    
    /// Indicates if this socket should be upgraded to SSL and how to upgrade
    var ssl: MySQLSSLConfig?
    
    /// A future promise
    var authenticated = Promise<Void>()
    
    /// The inserted ID from the last successful query
    public var lastInsertID: UInt64?
    
    /// Amount of affected rows in the last successful query
    public var affectedRows: UInt64?
    
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
        port: UInt16 = 3306,
        ssl: MySQLSSLConfig? = nil,
        user: String,
        password: String?,
        database: String,
        client: TCPClient,
        eventLoop: EventLoop
    ) throws {
        let parser = MySQLPacketParser()
        self.authenticated = Promise<Void>()
        self.client = client
        self.socket = client.socket
        self.ssl = ssl
        self.parser = parser
        self.username = user
        self.password = password
        self.database = database
        self.eventLoop = eventLoop
        
        client
            .stream(on: eventLoop)
            .stream(to: parser)
            .output(to: self)
    }

    deinit {
        self.close()
    }
    
    /// Closes the connection
    public func close() {
        // Write `close`
        _ = try? self.write(packetFor: Data([0x01]))
        self.socket.close()
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
    ) throws -> MySQLConnection {
        let socket = try TCPSocket()
        let client = try TCPClient(socket: socket)
        
        try client.connect(hostname: hostname, port: port)
        
        return try MySQLConnection(
            hostname: hostname,
            port: port,
            ssl: ssl,
            user: user,
            password: password,
            database: database,
            on: client,
            eventLoop: eventLoop
        )
    }
}
