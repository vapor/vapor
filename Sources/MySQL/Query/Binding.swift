import Bits
import Foundation

/// https://mariadb.com/kb/en/library/packet_bindata/
///
/// TODO: Geometry, Enum, Set
/// TODO: Date related types
extension PreparationBinding {
    /// TODO: Better method? This is the "official" way
    /// https://mariadb.com/kb/en/library/packet_bindata/
    public func bind(decimal: String) throws {
        try self.bind(fieldType: .decimal, unsigned: false, data: decimal.makeData())
    }
    
    /// TODO: Better method? This is the "official" way
    /// https://mariadb.com/kb/en/library/packet_bindata/
    public func bind(newDecimal: String) throws {
        try self.bind(fieldType: .newdecimal, unsigned: false, data: newDecimal.makeData())
    }
    
    public func bind(_ int: Int8) throws {
        try self.bind(fieldType: .tiny, unsigned: false, data: Data([numericCast(int)]))
    }
    
    public func bind(_ int: UInt8) throws {
        try self.bind(fieldType: .tiny, unsigned: true, data: Data([int]))
    }
    
    public func bind(_ int: Int16) throws {
        try self.bind(
            fieldType: .short,
            unsigned: false,
            data: int.makeData()
        )
    }
    
    public func bind(_ int: UInt16) throws {
        try self.bind(
            fieldType: .short,
            unsigned: false,
            data: int.makeData()
        )
    }
    
    /// Binds to either Int32 or Int24
    public func bind(_ int: Int32) throws {
        try self.bind(
            fieldType: .long,
            unsigned: false,
            data: int.makeData()
        )
    }
    
    /// Binds to either UInt32 or UInt24
    public func bind(_ int: UInt32) throws {
        try self.bind(
            fieldType: .long,
            unsigned: true,
            data: int.makeData()
        )
    }
    
    public func bind(_ int: Int) throws {
        #if arch(x86_64) || arch(arm64)
            try self.bind(numericCast(int) as Int32)
        #else
            try self.bind(numericCast(int) as Int64)
        #endif
    }
    
    public func bind(_ int: UInt) throws {
        #if arch(x86_64) || arch(arm64)
            try self.bind(numericCast(int) as UInt32)
        #else
            try self.bind(numericCast(int) as UInt64)
        #endif
    }
    
    public func bind(_ int: Int64) throws {
        try self.bind(
            fieldType: .longlong,
            unsigned: false,
            data: int.makeData()
        )
    }
    
    public func bind(_ int: UInt64) throws {
        try self.bind(
            fieldType: .longlong,
            unsigned: true,
            data: int.makeData()
        )
    }
    
    /// TODO: Float/Float64?
    /// MariaDB doesn't support those directly
    public func bind(_ float: Float32) throws {
        try self.bind(
            fieldType: .float,
            unsigned: true,
            data: float.makeData(size: 4)
        )
    }
    
    public func bind(varChar: String) throws {
        try self.bind(fieldType: .varchar, unsigned: false, data: varChar.makeData())
    }
    
    public func bind(tinyBlob data: Data) throws {
        try self.bind(fieldType: .tinyBlob, unsigned: false, data: data.makeLenEnc())
    }
    
    public func bind(mediumBlob data: Data) throws {
        try self.bind(fieldType: .mediumBlob, unsigned: false, data: data.makeLenEnc())
    }
    
    public func bind(longBlob data: Data) throws {
        try self.bind(fieldType: .longBlob, unsigned: false, data: data.makeLenEnc())
    }
    
    public func bind(blob data: Data) throws {
        try self.bind(fieldType: .blob, unsigned: false, data: data.makeLenEnc())
    }
    
    public func bind(varString: String) throws {
        try self.bind(fieldType: .varString, unsigned: false, data: varString.makeData())
    }
    
    public func bind(string: String) throws {
        try self.bind(fieldType: .string, unsigned: false, data: string.makeData())
    }
}

extension FloatingPoint {
    fileprivate func makeData(size bytes: Int) -> Data {
        var int = self
        
        return withUnsafePointer(to: &int) { pointer in
            return pointer.withMemoryRebound(to: UInt8.self, capacity: bytes) { pointer in
                return Data(bytes: pointer, count: bytes)
            }
        }
    }
}

extension BinaryInteger {
    // TODO: Don't require length hint
    fileprivate func makeData() -> Data {
        var int = self
        
        let bytes = self.bitWidth / 8
        
        return withUnsafePointer(to: &int) { pointer in
            return pointer.withMemoryRebound(to: UInt8.self, capacity: bytes) { pointer in
                return Data(bytes: pointer, count: bytes)
            }
        }
    }
}

extension String {
    fileprivate func makeData() -> Data {
        return Data(self.utf8).makeLenEnc()
    }
}

extension Data {
    fileprivate func makeLenEnc() -> Data {
        if self.count < 0xfc {
            return Data([numericCast(self.count)]) + self
        } else if self.count <= numericCast(UInt16.max) {
            var lenEnc = Data(repeating: 0xfc, count: 3)
            
            lenEnc.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
                pointer.advanced(by: 1).withMemoryRebound(to: UInt16.self, capacity: 1) { pointer in
                    pointer.pointee = numericCast(self.count)
                }
            }
            
            return lenEnc + self
        } else if self.count <= numericCast(UInt32.max) {
            var lenEnc = Data(repeating: 0xfd, count: 5)
            
            lenEnc.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
                pointer.advanced(by: 1).withMemoryRebound(to: UInt32.self, capacity: 1) { pointer in
                    pointer.pointee = numericCast(self.count)
                }
            }
            
            return lenEnc + self
        } else {
            var lenEnc = Data(repeating: 0xfe, count: 9)
            
            lenEnc.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
                pointer.advanced(by: 1).withMemoryRebound(to: UInt64.self, capacity: 1) { pointer in
                    pointer.pointee = numericCast(self.count)
                }
            }
            
            return lenEnc + self
        }
    }
}
