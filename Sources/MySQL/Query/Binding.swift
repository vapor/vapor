import Bits
import Foundation

/// https://mariadb.com/kb/en/library/packet_bindata/
///
/// TODO: Geometry, Enum, Set
/// TODO: Date related types
extension PreparationBinding {
    /// TODO: Better method? This is the "official" way
    /// https://mariadb.com/kb/en/library/packet_bindata/
    ///
    /// Binds to the first unbound parameter
    ///
    /// - throws: If the next unbound parameter is of a different type or if there are no more unbound parameters
    public func bind(decimal: String) throws {
        try self.bind(.decimal, unsigned: false, data: decimal.makeData())
    }
    
    /// TODO: Better method? This is the "official" way
    /// https://mariadb.com/kb/en/library/packet_bindata/
    ///
    /// Binds to the first unbound parameter
    ///
    /// - throws: If the next unbound parameter is of a different type or if there are no more unbound parameters
    public func bind(newDecimal: String) throws {
        try self.bind(.decimal, unsigned: false, data: newDecimal.makeData())
    }
    
    /// Binds an Int8
    ///
    /// Binds to the first unbound parameter
    ///
    /// - throws: If the next unbound parameter is of a different type or if there are no more unbound parameters
    public func bind(_ int: Int8) throws {
        try self.bind(.int, unsigned: false, data: Data([numericCast(int)]))
    }
    
    /// Binds an UInt8
    ///
    /// Binds to the first unbound parameter
    ///
    /// - throws: If the next unbound parameter is of a different type or if there are no more unbound parameters
    public func bind(_ int: UInt8) throws {
        try self.bind(.int, unsigned: true, data: Data([int]))
    }
    
    /// Binds an Int16
    ///
    /// Binds to the first unbound parameter
    ///
    /// - throws: If the next unbound parameter is of a different type or if there are no more unbound parameters
    public func bind(_ int: Int16) throws {
        try self.bind(
            .int,
            unsigned: false,
            data: int.makeData()
        )
    }
    
    /// Binds an UInt16
    ///
    /// Binds to the first unbound parameter
    ///
    /// - throws: If the next unbound parameter is of a different type or if there are no more unbound parameters
    public func bind(_ int: UInt16) throws {
        try self.bind(
            .int,
            unsigned: false,
            data: int.makeData()
        )
    }
    
    /// Binds to either Int32 or Int24
    ///
    /// Binds to the first unbound parameter
    ///
    /// - throws: If the next unbound parameter is of a different type or if there are no more unbound parameters
    public func bind(_ int: Int32) throws {
        try self.bind(
            .int,
            unsigned: false,
            data: int.makeData()
        )
    }
    
    /// Binds to either UInt32 or UInt24
    ///
    /// Binds to the first unbound parameter
    ///
    /// - throws: If the next unbound parameter is of a different type or if there are no more unbound parameters
    public func bind(_ int: UInt32) throws {
        try self.bind(
            .int,
            unsigned: true,
            data: int.makeData()
        )
    }
    
    /// Binds to an `Int32` or `Int64` depending on the processor architecture
    ///
    /// Binds to the first unbound parameter
    ///
    /// - throws: If the next unbound parameter is of a different type or if there are no more unbound parameters
    public func bind(_ int: Int) throws {
        #if arch(x86_64) || arch(arm64)
            try self.bind(numericCast(int) as Int32)
        #else
            try self.bind(numericCast(int) as Int64)
        #endif
    }
    
    /// Binds to an `UInt32` or `UInt64` depending on the processor architecture
    ///
    /// Binds to the first unbound parameter
    ///
    /// - throws: If the next unbound parameter is of a different type or if there are no more unbound parameters
    public func bind(_ int: UInt) throws {
        #if arch(x86_64) || arch(arm64)
            try self.bind(numericCast(int) as UInt64)
        #else
            try self.bind(numericCast(int) as UInt32)
        #endif
    }
    
    /// Binds to an `Int64`
    ///
    /// Binds to the first unbound parameter
    ///
    /// - throws: If the next unbound parameter is of a different type or if there are no more unbound parameters
    public func bind(_ int: Int64) throws {
        try self.bind(
            .int,
            unsigned: false,
            data: int.makeData()
        )
    }
    
    /// Binds to an `UInt64`
    ///
    /// Binds to the first unbound parameter
    ///
    /// - throws: If the next unbound parameter is of a different type or if there are no more unbound parameters
    public func bind(_ int: UInt64) throws {
        try self.bind(
            .int,
            unsigned: true,
            data: int.makeData()
        )
    }
    
    /// Binds to a float
    ///
    /// Binds to the first unbound parameter
    ///
    /// - throws: If the next unbound parameter is of a different type or if there are no more unbound parameters
    /// - TODO: Float/Float64? MariaDB doesn't support those directly
    public func bind(_ float: Float32) throws {
        try self.bind(
            .float,
            unsigned: true,
            data: float.makeData(size: 4)
        )
    }
    
    /// Binds to a `Double`
    public func bind(_ double: Double) throws {
        try self.bind(.double, unsigned: false, data: double.makeData(size: 8))
    }
    
    /// Binds to a `Blob`, doesn't require specifying the type of blob
    public func bind(_ data: Data) throws {
        try self.bind(.blob, unsigned: false, data: data.makeLenEnc())
    }
    
    /// Binds to a `varchar`, `string` or `varString`, doesn't require specifying the type of string
    public func bind(_ string: String) throws {
        try self.bind(.string, unsigned: false, data: string.makeData())
    }
}

enum PseudoType {
    case decimal
    case int
    case double
    case float
    case blob
    case string
    
    func supports(_ type: Field.FieldType) -> Bool {
        switch self {
        case .decimal:
            return type == .decimal || type == .newdecimal
        case .int:
            return type == .int24 || type == .tiny || type == .long || type == .short || type == .longlong
        case .double:
            return type == .double
        case .float:
            return type == .float
        case .blob:
            return type == .blob || type == .longBlob || type == .tinyBlob || type == .mediumBlob
        case .string:
            return type == .varString || type == .varString || type == .string
        }
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
    /// Enocodes the string using lenEnc
    ///
    /// - TODO: Collations?
    fileprivate func makeData() -> Data {
        return Data(self.utf8).makeLenEnc()
    }
}

extension Data {
    /// Enocodes the data using lenEnc
    fileprivate func makeLenEnc() -> Data {
        /// < 0xfc we can use the literal count
        if self.count < 0xfc {
            return Data([numericCast(self.count)]) + self
        // <= UInt16.max we need to prefix with `0xfc` and the append the length
        } else if self.count <= numericCast(UInt16.max) {
            var lenEnc = Data(repeating: 0xfc, count: 3)
            
            lenEnc.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
                pointer.advanced(by: 1).withMemoryRebound(to: UInt16.self, capacity: 1) { pointer in
                    pointer.pointee = numericCast(self.count)
                }
            }
            
            return lenEnc + self
        // <= UInt32.max we need to prefix with `0xfd` and the append the length
        } else if self.count <= numericCast(UInt32.max) {
            var lenEnc = Data(repeating: 0xfd, count: 5)
            
            lenEnc.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
                pointer.advanced(by: 1).withMemoryRebound(to: UInt32.self, capacity: 1) { pointer in
                    pointer.pointee = numericCast(self.count)
                }
            }
            
            return lenEnc + self
        // <= UInt64.max we need to prefix with `0xfe` and the append the length
        } else {
            var lenEnc = Data(repeating: 0xfe, count: 9)
            
            lenEnc.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
                pointer.advanced(by: 1).withMemoryRebound(to: UInt64.self, capacity: 1) { pointer in
                    pointer.pointee = numericCast(self.count)
                }
            }
            
            return lenEnc + self
        }
        // 0xff is unused, unsupported and reserved
    }
}
