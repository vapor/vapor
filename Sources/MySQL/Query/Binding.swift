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
        let type = boundStatement.statement.parameters[boundStatement.boundParameters].fieldType
        
        if try PseudoType.int.supports(expecting: type) == .text {
            try self.bind(
                .string,
                unsigned: false,
                data: int.description.makeData()
            )
            
            return
        }
        
        try self.bind(
            type,
            unsigned: false,
            data: Data([numericCast(int)])
        )
    }
    
    /// Binds an UInt8
    ///
    /// Binds to the first unbound parameter
    ///
    /// - throws: If the next unbound parameter is of a different type or if there are no more unbound parameters
    public func bind(_ int: UInt8) throws {
        let type = boundStatement.statement.parameters[boundStatement.boundParameters].fieldType
        
        if try PseudoType.int.supports(expecting: type) == .text {
            try self.bind(
                .string,
                unsigned: false,
                data: int.description.makeData()
            )
            
            return
        }
        
        try self.bind(
            type,
            unsigned: true,
            data: Data([int])
        )
    }
    
    /// Binds an Int16
    ///
    /// Binds to the first unbound parameter
    ///
    /// - throws: If the next unbound parameter is of a different type or if there are no more unbound parameters
    public func bind(_ int: Int16) throws {
        let type = boundStatement.statement.parameters[boundStatement.boundParameters].fieldType
        
        if try PseudoType.int.supports(expecting: type) == .text {
            try self.bind(
                .string,
                unsigned: false,
                data: int.description.makeData()
            )
            
            return
        }
        
        try self.bind(
            type,
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
        let type = boundStatement.statement.parameters[boundStatement.boundParameters].fieldType
        
        if try PseudoType.int.supports(expecting: type) == .text {
            try self.bind(
                .string,
                unsigned: false,
                data: int.description.makeData()
            )
            
            return
        }
        
        try self.bind(
            type,
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
        let type = boundStatement.statement.parameters[boundStatement.boundParameters].fieldType
        
        if try PseudoType.int.supports(expecting: type) == .text {
            try self.bind(
                .string,
                unsigned: false,
                data: int.description.makeData()
            )
            
            return
        }
        
        try self.bind(
            type,
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
        let type = boundStatement.statement.parameters[boundStatement.boundParameters].fieldType
        
        if try PseudoType.int.supports(expecting: type) == .text {
            try self.bind(
                .string,
                unsigned: false,
                data: int.description.makeData()
            )
            
            return
        }
        
        try self.bind(
            type,
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
            if try PseudoType.int.supports(expecting: .longlong) == .text {
                try self.bind(
                    .string,
                    unsigned: false,
                    data: int.description.makeData()
                )
                
                return
            }
            
            try self.bind(numericCast(int) as Int64)
        #else
            if try PseudoType.int.supports(expecting: .long) == .text {
                try self.bind(
                    .string,
                    unsigned: true,
                    data: int.description.makeData()
                )
                
                return
            }
            
            try self.bind(numericCast(int) as Int32)
        #endif
    }
    
    /// Binds to an `UInt32` or `UInt64` depending on the processor architecture
    ///
    /// Binds to the first unbound parameter
    ///
    /// - throws: If the next unbound parameter is of a different type or if there are no more unbound parameters
    public func bind(_ int: UInt) throws {
        #if arch(x86_64) || arch(arm64)
            if try PseudoType.int.supports(expecting: .longlong) == .text {
                try self.bind(
                    .string,
                    unsigned: false,
                    data: int.description.makeData()
                )
                
                return
            }
            
            try self.bind(numericCast(int) as UInt64)
        #else
            if try PseudoType.int.supports(expecting: .long) == .text {
                try self.bind(
                    .string,
                    unsigned: true,
                    data: int.description.makeData()
                )
                
                return
            }
            
            try self.bind(numericCast(int) as UInt32)
        #endif
    }
    
    /// Binds to an `Int64`
    ///
    /// Binds to the first unbound parameter
    ///
    /// - throws: If the next unbound parameter is of a different type or if there are no more unbound parameters
    public func bind(_ int: Int64) throws {
        let type = boundStatement.statement.parameters[boundStatement.boundParameters].fieldType
        
        if try PseudoType.int.supports(expecting: type) == .text {
            try self.bind(
                .string,
                unsigned: false,
                data: int.description.makeData()
            )
            
            return
        }
        
        try self.bind(
            type,
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
        let type = boundStatement.statement.parameters[boundStatement.boundParameters].fieldType
        
        if try PseudoType.int.supports(expecting: type) == .text {
            try self.bind(
                .string,
                unsigned: false,
                data: int.description.makeData()
            )
            
            return
        }
        
        try self.bind(
            type,
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
        let type = boundStatement.statement.parameters[boundStatement.boundParameters].fieldType
        
        if try PseudoType.double.supports(expecting: type) == .text {
            try self.bind(
                .string,
                unsigned: false,
                data: float.description.makeData()
            )
            
            return
        }
        
        try self.bind(
            .float,
            unsigned: true,
            data: float.makeData(size: 4)
        )
    }
    
    public func bind(date: Date) throws {
        let type = boundStatement.statement.parameters[boundStatement.boundParameters].fieldType
        
        if try PseudoType.double.supports(expecting: type) == .text {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            
            try self.bind(
                .string,
                unsigned: false,
                data: formatter.string(from: date).makeData()
            )
            
            return
        }
        
        switch type {
        case .datetime:
            let calendar = Calendar(identifier: .gregorian)
            
            let components = calendar.dateComponents(
                [
                    .year,
                    .month,
                    .day,
                    .hour,
                    .minute,
                    .second
                ],
                from: date
            )
            
            guard
                let year = components.year,
                let month = components.month,
                let day = components.day,
                let hour = components.hour,
                let minute = components.minute,
                let second = components.second,
                year < Int16.max,
                year > Int16.min
            else {
                throw MySQLError(
                    .invalidBinding(for: type)
                )
            }
            
            let yearInt16: Int16 = numericCast(year)
            
            let data = Data([
                numericCast(yearInt16.bigEndian >> 8),
                numericCast(yearInt16.bigEndian & 0xff),
                numericCast(month),
                numericCast(month),
                numericCast(day),
                numericCast(hour),
                numericCast(minute),
                numericCast(second),
            ])
            
            try bind(type, unsigned: false, data: data)
        default:
            throw MySQLError(
                .invalidBinding(for: type)
            )
        }
    }
    
    /// Binds to a `Double`
    public func bind(_ double: Double) throws {
        let type = boundStatement.statement.parameters[boundStatement.boundParameters].fieldType
        
        if try PseudoType.double.supports(expecting: type) == .text {
            try self.bind(
                .string,
                unsigned: false,
                data: double.description.makeData()
            )
            
            return
        }
        
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
    
    func supports(expecting expectation: Field.FieldType) throws -> MySQLEncoding {
        if expectation == .varString {
            return .text
        }
        
        switch self {
        case .decimal:
            if expectation == .decimal || expectation == .newdecimal {
                return .binary
            }
        case .int:
            if expectation == .int24 || expectation == .tiny || expectation == .long || expectation == .short || expectation == .longlong {
                return .binary
            }
        case .double:
            if expectation == .double {
                return .binary
            }
        case .float:
            if expectation == .float {
                return .binary
            }
        case .blob:
            if expectation == .blob || expectation == .longBlob || expectation == .tinyBlob || expectation == .mediumBlob {
                return .binary
            }
        case .string:
            if expectation == .varchar || expectation == .varString || expectation == .string {
                return .binary
            }
        }
        
        throw MySQLError(
            .invalidTypeBound(
                got: self,
                expected: expectation
            )
        )
    }
}

enum MySQLEncoding {
    case text
    case binary
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
