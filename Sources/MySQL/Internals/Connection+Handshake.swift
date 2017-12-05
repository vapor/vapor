import Async
import Bits
import Crypto
import Core
import Foundation

extension MySQLConnection {
    /// Respond to the server's incoming handshake
    func doHandshake(for packet: Packet) {
        do {
            let handshake = try packet.parseHandshake()
            self.handshake = handshake
            
            try self.sendHandshake()
        } catch {
            self.authenticated.fail(error)
            self.socket.close()
        }
    }
    
    /// Send the handshake to the client
    func sendHandshake() throws {
        guard let handshake = self.handshake else {
            throw MySQLError(.invalidHandshake)
        }
        
        if handshake.isGreaterThan4 {
            var size = 32 + self.username.utf8.count + 1 + database.utf8.count + 1
            
            if let password = self.password, handshake.capabilities.contains(.secureConnection) {
                size += 21
            } else {
                size += 1
            }
            
            if let scheme = handshake.authenticationScheme, handshake.capabilities.contains(.pluginAuth) {
                size += scheme.utf8.count + 1
            }
            
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
            
            if let scheme = handshake.authenticationScheme, handshake.capabilities.contains(.pluginAuth) {
                memcpy(writer, scheme, scheme.utf8.count)
                writer += scheme.utf8.count + 1
            }
            
            let data = ByteBuffer(start: pointer, count: size)
            
            try self.write(packetFor: data, startingAt: 1)
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
    func finishAuthentication(for packet: Packet, completing: Promise<Void>) {
        do {
            switch packet.payload.first {
            case 0xfe:
                if packet.payload.count == 0 {
                    completing.fail(MySQLError(.invalidHandshake))
                } else {
                    var offset = 1
                    
                    while offset < packet.payload.count, packet.payload[offset] != 0x00 {
                        offset = offset &+ 1
                    }
                    
                    guard
                        let password = self.password,
                        let mechanism = String(bytes: packet.payload[1..<offset], encoding: .utf8)
                    else {
                        completing.fail(MySQLError(.invalidHandshake))
                        return
                    }
                    
                    switch mechanism {
                    case "mysql_native_password":
                        guard offset &+ 1 < packet.payload.count else {
                            completing.fail(MySQLError(.invalidHandshake))
                            return
                        }
                        
                        let hash = sha1Encrypted(from: password, seed: Array(packet.payload[(offset &+ 1)...]))
                        
                        try self.write(packetFor: hash)
                    case "mysql_clear_password":
                        try self.write(packetFor: Data(password.utf8))
                    default:
                        completing.fail(MySQLError(.invalidHandshake))
                    }
                }
            case 0xff:
                completing.fail(MySQLError(packet: packet))
            default:
                // auth is finished, have the parser stream to the packet stream now
                parser.stream(to: packetStream)
                completing.complete()
            }
            
            let response = try packet.parseResponse(mysql41: self.mysql41)
            
            switch response {
            case .error(let error):
                completing.fail(error)
                // Unauthenticated
                self.socket.close()
                return
            default:
                return
            }
        } catch {
            self.authenticated.fail(error)
            self.socket.close()
        }
    }
}


