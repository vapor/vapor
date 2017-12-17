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
    /// The state of the server's handshake
    var handshake: Handshake
    
    /// The incoming stream parser
    let parser: MySQLPacketParser
    
    let serializer: MySQLPacketSerializer
    
    let streamClose: () -> ()
    
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
        return handshake.isGreaterThan4 == true && self.capabilities.contains(.protocol41) && handshake.capabilities.contains(.protocol41) == true
    }
    
    /// Creates a new connection
    ///
    /// Doesn't finish the handshake synchronously
    init(
        handshake: Handshake,
        stream: AnyStream<ByteBuffer, ByteBuffer>
    ) throws {
        self.streamClose = stream.close
        self.handshake = handshake
        self.parser = stream.stream(to: MySQLPacketParser())
        self.serializer = MySQLPacketSerializer()
        
        serializer.output(to: stream)
    }

    deinit {
        self.close()
    }
    
    /// Closes the connection
    public func close() {
        // Write `close`
        serializer.queue([
            0x01 // close identifier
        ])
        
        streamClose()
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
        let client = TCPClient(socket: socket)
        
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
