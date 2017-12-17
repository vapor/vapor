import Bits
import Async

/// Keeps track of the server's handshake parameters
///
/// https://mariadb.com/kb/en/library/1-connecting-connecting/
struct Handshake {
    /// The server protocol version
    let version = 10
    
    /// The server's instance version
    let serverVersion: String
    
    /// The thread used for managing the client
    let threadId: UInt32
    
    /// The server's capabilities
    let capabilities: Capabilities
    
    /// The database's default collation
    let defaultCollation: UInt8
    
    /// ???
    let serverStatus: UInt16
    
    /// A salt/seed that is mixed with the password to produce a hash
    let randomSeed: [UInt8]
    
    /// The authentication scheme to use
    ///
    /// Normally `mysql_native_password` (the only supported one)
    var authenticationScheme: String?
    
    /// The MySQL >=4.1 uses a stronger seed and has more capabilities
    var isGreaterThan4: Bool {
        return authenticationScheme != nil || randomSeed.count > 8
    }
}

extension Packet {
    /// Parses this packet into the server's handshake
    func parseHandshake() throws -> Handshake {
        let length = payload.count
        
        var parser = Parser(packet: self)
        
        // Require decimal `10` to be the protocol version
        guard try parser.byte() == 10 else {
            throw MySQLError(.invalidHandshake)
        }
        
        // UTF-8
        var serverVersionBuffer = [UInt8]()
        
        // Parse the server's version
        while parser.position < length, payload[parser.position] != 0 {
            serverVersionBuffer.append(try parser.byte())
        }
        
        guard try parser.byte() == 0 else {
            throw MySQLError(.invalidHandshake)
        }
        
        guard let serverVersion = String(bytes: serverVersionBuffer, encoding: .utf8) else {
            throw MySQLError(.invalidHandshake)
        }
        
        // ID of the MySQL internal thread handling this connection
        let threadId = try parser.parseUInt32()
        
        // 8 bytes of the random seed
        var randomSeed = try parser.buffer(length: 8)
        
        // null terminator of the random seed
        guard try parser.byte() == 0 else {
            throw MySQLError(.invalidHandshake)
        }
        
        // capabilities + default collation
        
        // two of the possible 4 server capabilities bytes
        let capabilities = Capabilities(rawValue: UInt32(try parser.parseUInt16()))
        
        let defaultCollation = try parser.byte()
        
        let serverStatus = try parser.parseUInt16()
        
        // 13 reserved bytes
        try parser.require(13)
        parser.position = parser.position &+ 13
        
        var authenticationScheme: String? = nil
        
        // if MySQL server version >= 4.1
        if parser.position &+ 13 < length {
            // 12 extra random seed bytes
            randomSeed.append(contentsOf: try parser.buffer(length: 12))
            
            guard try parser.byte() == 0 else {
                throw MySQLError(.invalidHandshake)
            }
            
            if parser.position < payload.count &- 1 {
                authenticationScheme = String(bytes: payload[parser.position..<payload.count &- 1], encoding: .utf8)
            }
        }
        
        return Handshake(serverVersion: serverVersion,
                         threadId: threadId,
                         capabilities: capabilities,
                         defaultCollation: defaultCollation,
                         serverStatus: serverStatus,
                         randomSeed: randomSeed,
                         authenticationScheme: authenticationScheme)
    }
}
