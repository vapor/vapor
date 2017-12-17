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
    
    /// Creates a new connection
    ///
    /// Doesn't finish the handshake synchronously
    init(
        handshake: Handshake,
        stream: AnyStream<ByteBuffer, ByteBuffer>
    ) {
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

