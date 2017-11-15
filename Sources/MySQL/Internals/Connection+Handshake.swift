import Async
import Bits
import Crypto
import Core
import Foundation

extension Connection {
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
            throw MySQLError(.invalidHandshake)
        }
    }
    
    /// Parse the authentication request
    func finishAuthentication(for packet: Packet, completing: Promise<Void>) {
        do {
            let response = try packet.parseResponse(mysql41: self.mysql41)
            
            switch response {
            case .error(_):
                completing.fail(MySQLError(.invalidCredentials))
                // Unauthenticated
                self.socket.close()
                return
            default:
                completing.complete(())
                return
            }
        } catch {
            self.socket.close()
        }
    }
}


