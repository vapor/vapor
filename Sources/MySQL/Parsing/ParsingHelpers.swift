import Foundation
import Core

class Parser {
    var position: Int
    var packet: Packet
    
    init(packet: Packet, position: Int = 0) {
        self.packet = packet
        self.position = position
    }
    
    var payload: MutableByteBuffer {
        return packet.payload
    }
    
    func require(_ n: Int) throws {
        guard position &+ n < packet.payload.count else {
            throw MySQLError.invalidHandshake
        }
    }
    
    func byte() throws -> UInt8 {
        try require(1)
        
        defer { position = position &+ 1 }
        
        return self.payload[position]
    }
    
    func buffer(length: Int) throws -> [UInt8] {
        try require(length)
        
        defer { position = position &+ length }
        
        return Array(payload[position..<position &+ length])
    }
    
    func parseUInt16() throws -> UInt16 {
        try require(2)
        
        defer { position = position &+ 2 }
        
        let byte0 = UInt16(self.payload[position])
        let byte1 = UInt16(self.payload[position &+ 1]) << 8
        
        return byte0 | byte1
    }
    
    func parseUInt32() throws -> UInt32 {
        try require(4)
        
        defer { position = position &+ 4 }
        
        let byte0 = UInt32(self.payload[position])
        let byte1 = UInt32(self.payload[position &+ 1]) << 8
        let byte2 = UInt32(self.payload[position &+ 2]) << 16
        let byte3 = UInt32(self.payload[position &+ 3]) << 24
        
        return byte0 | byte1 | byte2 | byte3
    }
    
    func parseUInt64() throws -> UInt64 {
        try require(8)
        
        defer { position = position &+ 8 }
        
        let byte0 = UInt64(self.payload[position])
        let byte1 = UInt64(self.payload[position &+ 1]) << 8
        let byte2 = UInt64(self.payload[position &+ 2]) << 16
        let byte3 = UInt64(self.payload[position &+ 3]) << 24
        let byte4 = UInt64(self.payload[position &+ 4]) << 32
        let byte5 = UInt64(self.payload[position &+ 5]) << 40
        let byte6 = UInt64(self.payload[position &+ 6]) << 48
        let byte7 = UInt64(self.payload[position &+ 7]) << 56
        
        return byte0 | byte1 | byte2 | byte3 | byte4 | byte5 | byte6 | byte7
    }
    
    func parseLenEnc() throws -> UInt64 {
        guard position < self.payload.count else {
            throw MySQLError.invalidResponse
        }
        
        switch self.payload[position] {
        case 0xfc:
            position = position &+ 1
            
            return UInt64(try parseUInt16())
        case 0xfd:
            position = position &+ 1
            
            return UInt64(try parseUInt32())
        case 0xfe:
            position = position &+ 1
            
            return try parseUInt64()
        case 0xff:
            throw MySQLError.invalidResponse
        default:
            defer { position = position &+ 1 }
            return UInt64(self.payload[position])
        }
    }
    
    func parseLenEncData() throws -> Data {
        let length = Int(try parseLenEnc())
        
        guard position &+ length <= self.payload.count else {
            throw MySQLError.invalidResponse
        }
        
        defer { position = position &+ length }
        
        return Data(self.payload[position..<position &+ length])
    }
    
    func parseLenEncString() throws -> String {
        let length = Int(try parseLenEnc())
        
        guard position &+ length <= self.payload.count else {
            throw MySQLError.invalidResponse
        }
        
        defer { position = position &+ length }
        
        return String(bytes: self.payload[position..<position &+ length], encoding: .utf8) ?? ""
    }
}
