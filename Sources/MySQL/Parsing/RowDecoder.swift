import JunkDrawer
import Foundation

func makeRowDecoder(row: Row, lossyIntegers: Bool, lossyStrings: Bool) throws -> Decoder {
    return try RowDecoder(keyed: row, lossyIntegers: lossyIntegers, lossyStrings: lossyStrings)
}

/// Decodes into an entity Rows into entities, and columns into variables
final class RowDecoder : DecoderHelper {
    /// Sets up a decoder for a row/struct/class
    required init(keyed: Row, lossyIntegers: Bool, lossyStrings: Bool) throws {
        self.either = .keyed(keyed)
        self.lossyIntegers = lossyIntegers
        self.lossyStrings = lossyStrings
    }

    /// Sets up a decoder for a column (variable)
    required init(value: Column, lossyIntegers: Bool, lossyStrings: Bool) throws {
        self.either = .value(value)
        self.lossyIntegers = lossyIntegers
        self.lossyStrings = lossyStrings
    }

    /// Unkeyed (arrays/sets) are not supported (yet)
    required init(unkeyed: NSNull, lossyIntegers: Bool, lossyStrings: Bool) throws {
        throw DecodingError.unimplemented
    }

    /// Creates a decoder for a column. Should decode nested structs, but that's not supported (yet)
    required init(any: Column, lossyIntegers: Bool, lossyStrings: Bool) throws {
        self.either = .value(any)
        self.lossyIntegers = lossyIntegers
        self.lossyStrings = lossyStrings
    }

    /// Maps a column to an integer, if it's an integer type
    func integers(for value: Column) throws -> Integers? {
        switch value {
        case .uint64(let num): return .uint64(num)
        case .int64(let num): return .int64(num)
        case .uint32(let num): return .uint32(num)
        case .int32(let num): return .int32(num)
        case .uint16(let num): return .uint16(num)
        case .int16(let num): return .int16(num)
        case .uint8(let num): return .uint8(num)
        case .int8(let num): return .int8(num)
        case .double(let num): return .double(num)
        // TODO: Date to epoch?
        case .float(let num): return .float(num)
        default: return nil
        }
    }
    
    /// Stores the current decoding context
    var either: Either<Column, Row, NSNull>
    
    /// Convert Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, UInt and Int automatically when possible
    ///
    /// Also converts Double and Float automatically
    var lossyIntegers: Bool
    
    /// Convert Strings and Numbers automatically when possible
    var lossyStrings: Bool
    
    /// Decodes a column to a String
    func decode(_ type: Column) throws -> String {
        if case .varString(let string) = type {
            return string
        } else {
            throw DecodingError.incorrectValue
        }
    }
    
    /// Decodes a column to a Bool, int8/uint8 is used here
    func decode(_ type: Column) throws -> Bool {
        if case .int8(let num) = type {
            return num == 1
        } else if case .uint8(let num) = type {
            return num == 1
        } else {
            throw DecodingError.incorrectValue
        }
    }
    
    func decode<D>(_ type: D.Type, from value: Column) throws -> D where D : Decodable {
        if D.self == Date.self, case .datetime(let date) = value {
            return date as! D
        }
        
        let newDecoder = try RowDecoder(any: value, lossyIntegers: self.lossyIntegers, lossyStrings: self.lossyStrings)
        
        return try D(from: newDecoder)
    }
    
    /// Columns contain values
    typealias Value = Column
    
    /// Rows are keyed sets
    typealias Keyed = Row
    
    /// Unkeyed (arrays) aren't supported
    typealias Unkeyed = NSNull
    
    /// The currently decoding keypath
    public var codingPath: [CodingKey] = []
    
    /// Unused, but required by protocol
    public var userInfo: [CodingUserInfoKey : Any] = [:]
    
    /// Creates a new RowContainer at a path
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        let container = RowContainer<Key>(decoder: self)
        return KeyedDecodingContainer(container)
    }
    
    /// Creates a new unkeyed container, will always throw since it's currently unsupported
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.unimplemented
    }
    
    /// Creates a new single value column container
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return ColumnContainer(decoder: self)
    }
}

extension Row : KeyedDecodingHelper {
    /// Makes Row conform to KeyedDecodingHelper to help decoding
    func value(forKey key: String) throws -> Column? {
        if let index = fieldNames.index(of: key) {
            return columns[index]
        }
        
        return nil
    }
}

/// Used for decoding a row's values
fileprivate struct RowContainer<Key : CodingKey>: KeyedDecodingContainerProtocolHelper {
    /// The coding path being accessed
    var codingPath: [CodingKey]
    
    /// A reference to the current decoder state
    let decoder: RowDecoder
    
    /// Lossy converts nil
    ///
    /// If there's no such value, make it nill. Require `NULL` otherwise
    func decodeNil(forKey key: Key) throws -> Bool {
        guard let value = try value(forKey: key) else {
            return true
        }
        
        if case .null = value {
            return true
        }
        
        return false
    }
    
    init(decoder: RowDecoder) {
        self.decoder = decoder
        self.codingPath = decoder.codingPath
    }
    
    /// Computes a list of all keys inside this row
    var allKeys: [Key] {
        guard case .keyed(let keyed) = decoder.either else {
            return []
        }
        
        return keyed.fieldNames.flatMap { name in
            return Key(stringValue: name)
        }
    }
    
    /// Checks if the key exists in this row
    func contains(_ key: Key) -> Bool {
        return (try? decoder.either.getKeyed().fieldNames.contains(key.stringValue)) == true
    }
}

/// Decodes a column's value
fileprivate struct ColumnContainer: SingleValueDecodingContainerHelper {
    /// The coding path being accessed
    var codingPath: [CodingKey]
    
    /// A reference to the current decoder state
    let decoder: RowDecoder
    
    /// Creates a new columncontainer
    init(decoder: RowDecoder) {
        self.decoder = decoder
        self.codingPath = decoder.codingPath
    }
    
    /// Decodes a generic decodable
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        let value = try singleValue()
        
        let d = try D(value: value, lossyIntegers: decoder.lossyIntegers, lossyStrings: decoder.lossyStrings)
        
        return try T(from: d)
    }
    
    func singleValue() throws -> Column {
        switch decoder.either {
        case .value(let column): return column
        case .unkeyed(_): throw MySQLError(.decodingError)
        case .keyed(let row):
            guard row.columns.count == 1 else {
                throw MySQLError(.decodingError)
            }
            
            return row.columns[0]
        }
    }
    
    /// Decodes this column as a string
    func decode(_ type: String.Type) throws -> String {
        return try decoder.decode(try singleValue())
    }
    
    /// Checks if this value is `nil`
    func decodeNil() -> Bool {
        guard let value = try? singleValue() else {
            return true
        }
        
        if case .null = value {
            return true
        }
        
        return false
    }
}
