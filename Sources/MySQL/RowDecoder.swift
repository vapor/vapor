import Foundation

class RowDecoder : DecoderHelper {
    required init(keyed: Row, lossyIntegers: Bool, lossyStrings: Bool) throws {
        self.either = .keyed(keyed)
        self.lossyIntegers = lossyIntegers
        self.lossyStrings = lossyStrings
    }

    required init(value: Column, lossyIntegers: Bool, lossyStrings: Bool) throws {
        self.either = .value(value)
        self.lossyIntegers = lossyIntegers
        self.lossyStrings = lossyStrings
    }

    required init(unkeyed: NSNull, lossyIntegers: Bool, lossyStrings: Bool) throws {
        throw DecodingError.unimplemented
    }

    required init(any: Column, lossyIntegers: Bool, lossyStrings: Bool) throws {
        self.either = .value(any)
        self.lossyIntegers = lossyIntegers
        self.lossyStrings = lossyStrings
    }

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
        case .float(let num): return .float(num)
        default: return nil
        }
    }
    
    var either: Either<Column, Row, NSNull>
    
    var lossyIntegers: Bool
    var lossyStrings: Bool
    
    init(from: RowDecoder) {
        self.either = from.either
        self.lossyIntegers = from.lossyIntegers
        self.lossyStrings = from.lossyStrings
    }
    
    public func decode(_ type: Column) throws -> String {
        let value = try either.getValue()
        
        if case .varString(let data) = value {
            guard let string = String(bytes: data, encoding: .utf8) else {
                throw DecodingError.incorrectValue
            }
            
            return string
        } else {
            throw DecodingError.incorrectValue
        }
    }
    
    public func decode(_ type: Column) throws -> Bool {
        let value = try either.getValue()
        
        if case .int8(let num) = value {
            return num == 1
        } else if case .uint8(let num) = value {
            return num == 1
        } else {
            throw DecodingError.incorrectValue
        }
    }
    
    typealias Value = Column
    typealias Keyed = Row
    typealias Unkeyed = NSNull
    
    public var codingPath: [CodingKey] = []
    
    public var userInfo: [CodingUserInfoKey : Any] = [:]
    
    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        let container = RowContainer<Key>(decoder: self)
        return KeyedDecodingContainer(container)
    }
    
    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.unimplemented
    }
    
    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        return ColumnContainer(decoder: self)
    }
}

extension Row : KeyedDecodingHelper {
    func value(forKey key: String) throws -> Column? {
        return self.fields.first { pair in
            return pair.field.name == key
        }?.column
    }
}

struct RowContainer<Key : CodingKey>: KeyedDecodingContainerProtocolHelper {
    var codingPath: [CodingKey]
    let decoder: RowDecoder
    
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
    
    var allKeys: [Key] {
        guard case .keyed(let keyed) = decoder.either else {
            return []
        }
        
        return keyed.fields.flatMap { pair in
            return Key(stringValue: pair.field.name)
        }
    }
    
    func contains(_ key: Key) -> Bool {
        return (try? decoder.either.getKeyed().fields.contains { pair in
            return pair.field.name == key.stringValue
        }) == true
    }
}

struct ColumnContainer: SingleValueDecodingContainerHelper {
    var codingPath: [CodingKey]
    let decoder: RowDecoder
    
    init(decoder: RowDecoder) {
        self.decoder = decoder
        self.codingPath = decoder.codingPath
    }
    
    public func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        let value = try decoder.either.getValue()
        
        let d = try D(value: value, lossyIntegers: decoder.lossyIntegers, lossyStrings: decoder.lossyStrings)
        
        return try T(from: d)
    }
    
    public func decode(_ type: String.Type) throws -> String {
        return try decoder.decode(try decoder.either.getValue())
    }
    
    public func decodeNil() -> Bool {
        guard let value = try? decoder.either.getValue() else {
            return true
        }
        
        if case .null = value {
            return true
        }
        
        return false
    }
}
