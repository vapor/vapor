import Bits
import Foundation

/// https://mariadb.com/kb/en/library/packet_bindata/
extension PreparationBinding {
//    public func bind(decimal: ???) throws {
//        try self.bind(fieldType: 0, unsigned: false, data: blob)
//    }
    
    public func bind(_ int: Int8) throws {
        try self.bind(fieldType: 1, unsigned: false, data: Data([numericCast(int)]))
    }
    
    public func bind(_ int: UInt8) throws {
        try self.bind(fieldType: 1, unsigned: true, data: Data([int]))
    }
    
    public func bind(_ int: Int16) throws {
        try self.bind(
            fieldType: 2,
            unsigned: false,
            data: Data([
                numericCast(int & 0xff),
                numericCast((int >> 8) & 0xff)
            ])
        )
    }
    
    public func bind(_ int: UInt16) throws {
        try self.bind(
            fieldType: 2,
            unsigned: false,
            data: Data([
                numericCast(int & 0xff),
                numericCast((int >> 8) & 0xff)
            ])
        )
    }
    
    public func bind(_ int: Int32) throws {
        try self.bind(
            fieldType: 3,
            unsigned: false,
            data: Data([
                numericCast(int & 0xff),
                numericCast((int >> 8) & 0xff),
                numericCast((int >> 16) & 0xff),
                numericCast((int >> 24) & 0xff)
            ])
        )
    }
    
    public func bind(_ int: UInt32) throws {
        try self.bind(
            fieldType: 3,
            unsigned: true,
            data: Data([
                numericCast(int & 0xff),
                numericCast((int >> 8) & 0xff),
                numericCast((int >> 16) & 0xff),
                numericCast((int >> 24) & 0xff)
            ])
        )
    }
    
    func encode(_ string: String) -> Data {
        let data = Data(string.utf8)
        
        if data.count < 0xfc {
            return Data([numericCast(data.count)]) + data
        } else if data.count <= numericCast(UInt16.max) {
            var lenEnc = Data(repeating: 0xfc, count: 3)
            
            lenEnc.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
                pointer.advanced(by: 1).withMemoryRebound(to: UInt16.self, capacity: 1) { pointer in
                    pointer.pointee = numericCast(data.count)
                }
            }
            
            return lenEnc + data
        } else if data.count <= numericCast(UInt32.max) {
            var lenEnc = Data(repeating: 0xfd, count: 5)
            
            lenEnc.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
                pointer.advanced(by: 1).withMemoryRebound(to: UInt32.self, capacity: 1) { pointer in
                    pointer.pointee = numericCast(data.count)
                }
            }
            
            return lenEnc + data
        } else {
            var lenEnc = Data(repeating: 0xfe, count: 9)
            
            lenEnc.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
                pointer.advanced(by: 1).withMemoryRebound(to: UInt64.self, capacity: 1) { pointer in
                    pointer.pointee = numericCast(data.count)
                }
            }
            
            return lenEnc + data
        }
    }
    
    public func bind(varChar: String) throws {
        try self.bind(fieldType: 15, unsigned: false, data: encode(varChar))
    }
    
    public func bind(tinyBlob data: Data) throws {
        try self.bind(fieldType: 249, unsigned: false, data: data)
    }
    
    public func bind(mediumBlob data: Data) throws {
        try self.bind(fieldType: 250, unsigned: false, data: data)
    }
    
    public func bind(longBlob data: Data) throws {
        try self.bind(fieldType: 251, unsigned: false, data: data)
    }
    
    public func bind(blob data: Data) throws {
        try self.bind(fieldType: 252, unsigned: false, data: data)
    }
    
    public func bind(varString: String) throws {
        try self.bind(fieldType: 253, unsigned: false, data: Data(varString.utf8))
    }
    
    public func bind(string: String) throws {
        try self.bind(fieldType: 254, unsigned: false, data: Data(string.utf8))
    }
}
