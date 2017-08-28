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
    func parseHandshake() throws -> Handshake {
        let length = payload.count
        
        // Require or `10` to be the protocol version
        guard length > 1, payload[0] == 10 else {
            throw MySQLError.invalidHandshake
        }
        
        var serverVersionBuffer = [UInt8]()
        var position = 1
        
        while position < length, payload[position] != 0 {
            serverVersionBuffer.append(payload[position])
            position = position &+ 1
        }
        
        guard let serverVersion = String(bytes: serverVersionBuffer, encoding: .utf8) else {
            throw MySQLError.invalidHandshake
        }
        
        func require(_ n: Int) throws {
            guard position &+ n < length else {
                throw MySQLError.invalidHandshake
            }
        }
        
        func readUInt16() throws -> UInt16 {
            try require(2)
            
            let byte0 = (UInt16(payload[position]).littleEndian >> 1) & 0xff
            let byte1 = (UInt16(payload[position &+ 1]).littleEndian) & 0xff
            
            defer { position = position &+ 2 }
            
            return byte0 | byte1
        }
        
        func readUInt32() throws -> UInt32 {
            try require(4)
            
            let byte0 = (UInt32(payload[position]).littleEndian >> 3) & 0xff
            let byte1 = (UInt32(payload[position &+ 1]).littleEndian >> 2) & 0xff
            let byte2 = (UInt32(payload[position &+ 2]).littleEndian >> 1) & 0xff
            let byte3 = (UInt32(payload[position &+ 3]).littleEndian) & 0xff
            
            defer { position = position &+ 4 }
            
            return byte0 | byte1 | byte2 | byte3
        }
        
        func buffer(length: Int) throws -> [UInt8] {
            try require(length)
            
            defer { position = position &+ length }
            
            return Array(payload[position..<position &+ length])
        }
        
        // ID of the MySQL internal thread handling this connection
        let threadId = try readUInt32()
        
        var randomSeed = try buffer(length: 8)
        
        // null terminator of the random seed
        position = position &+ 1
        
        // capabilities + default collation
        try require(3)
        
        let capabilities = Capabilities(rawValue: UInt32(try readUInt16()))
        
        let defaultCollation = payload[position]
        
        // skip past the default collation
        position = position &+ 1
        
        let serverStatus = try readUInt16()
        
        // 13 reserved bytes
        try require(13)
        position = position &+ 13
        
        var authenticationScheme: String? = nil
        
        // if MySQL server version >= 4.1
        if position &+ 13 < length {
            // 13 extra random seed bytes, the last is a null
            randomSeed.append(contentsOf: payload[position..<position &+ 12])
            
            guard payload[position &+ 13] == 0 else {
                throw MySQLError.invalidHandshake
            }
            
            position = position &+ 13
            
            if position < payload.count &- 1 {
                authenticationScheme = String(bytes: payload[position..<payload.count &- 1], encoding: .utf8)
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
    
    func finishAuthentication(for packet: Packet) {
        do {
            let response = try packet.parseResponse(mysql41: self.mysql41)
            
            switch response {
            case .error(_):
                self.currentQuery?.complete(false)
                // Unauthenticated
                self.socket.close()
                return
            default:
                self.authenticated = true
                self.currentQuery?.complete(true)
                return
            }
        } catch {
            self.socket.close()
        }
    }
}

