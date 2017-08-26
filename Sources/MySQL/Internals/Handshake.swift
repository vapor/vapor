struct Handshake {
    let version = 10
    let serverVersion: String
    let threadId: UInt32
    let capabilities: Capabilities
    let defaultCollation: UInt8
    let serverStatus: UInt16
    let randomSeed: [UInt8]
    var authenticationScheme: String?
    
    var isGreaterThan4: Bool {
        return authenticationScheme != nil || randomSeed.count > 8
    }
}

extension Packet {
    /// Parses this packet into the server's handshake
    func parseHandshake() throws -> Handshake {
        let length = payload.count
        
        let parser = Parser(packet: self)
        
        // Require decimal `10` to be the protocol version
        guard try parser.byte() == 10 else {
            throw MySQLError.invalidHandshake
        }
        
        // UTF-8
        var serverVersionBuffer = [UInt8]()
        
        // Parse the server's version
        while parser.position < length, payload[parser.position] != 0 {
            serverVersionBuffer.append(try parser.byte())
        }
        
        guard try parser.byte() == 0 else {
            throw MySQLError.invalidHandshake
        }
        
        guard let serverVersion = String(bytes: serverVersionBuffer, encoding: .utf8) else {
            throw MySQLError.invalidHandshake
        }
        
        // ID of the MySQL internal thread handling this connection
        let threadId = try parser.parseUInt32()
        
        // 8 bytes of the random seed
        var randomSeed = try parser.buffer(length: 8)
        
        // null terminator of the random seed
        guard try parser.byte() == 0 else {
            throw MySQLError.invalidHandshake
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
                throw MySQLError.invalidHandshake
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

import Foundation
import Crypto
import Core

extension Connection {
    func doHandshake(for packet: Packet) {
        do {
            let handshake = try packet.parseHandshake()
            self.handshake = handshake
            
            try self.sendHandshake()
        } catch {
            self.socket.close()
        }
    }
    
    func sendHandshake() throws {
        guard let handshake = self.handshake else {
            throw MySQLError.invalidHandshake
        }
        
        if handshake.isGreaterThan4 {
            let size = 32 + self.username.utf8.count + 1 + 1 + (password == nil ? 0 : 20) + (database?.count ?? -1) + 1
            let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
            pointer.initialize(to: 0, count: size)
            
            defer {
                pointer.deinitialize(count: size)
                pointer.deallocate(capacity: size)
            }
            
            let username = [UInt8](self.username.utf8)
            
            let combinedCapabilities = self.capabilities.rawValue & handshake.capabilities.rawValue
            
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
                let hashedPassword = SHA1.hash(password)
                let doublePasswordHash = SHA1.hash(hashedPassword)
                var hash = Array(SHA1.hash(handshake.randomSeed + doublePasswordHash))
                
                for i in 0..<20 {
                    hash[i] = hash[i] ^ hashedPassword[i]
                }
                
                // SHA1.digestSize == 20
                writer.pointee = 20
                writer += 1
            
                // SHA1 is always 20 long
                memcpy(writer, hash, 20)
                writer += 20
            } else {
                writer.pointee = 0
                writer += 1
            }
            
            if let database = database {
                let db = [UInt8](database.utf8) + [0]
                
                memcpy(writer, db, db.count)
                writer += database.count
            }
            
            let data = ByteBuffer(start: pointer, count: size)
            
            try self.write(packetFor: data, startingAt: 1)
        } else {
            throw MySQLError.invalidHandshake
        }
    }
    
    func finishAuthentication(for packet: Packet, completing: Promise<Void>) {
        do {
            let response = try packet.parseResponse(mysql41: self.mysql41)
            
            switch response {
            case .error(_):
                self.reserved = false
                completing.fail(MySQLError.invalidCredentials)
                // Unauthenticated
                self.socket.close()
                return
            default:
                completing.complete(())
                self.reserved = false
                return
            }
        } catch {
            self.socket.close()
        }
    }
}

