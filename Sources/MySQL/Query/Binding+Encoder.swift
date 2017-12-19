import CodableKit
import Foundation

extension PreparationBinding {
    public func withEncoder<T>(_ closure: (Encoder) throws -> T) rethrows -> T {
        let encoder = MySQLBindingEncoder(binding: self)
        
        return try closure(encoder)
    }
}

fileprivate final class MySQLBindingEncoder: Encoder {
    fileprivate var codingPath = [CodingKey]()
    fileprivate var userInfo = [CodingUserInfoKey: Any]()
    fileprivate let context: PreparationBinding
    
    fileprivate init(binding: PreparationBinding) {
        self.context = binding
    }
    
    fileprivate func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        return KeyedEncodingContainer(RowEncodingContainer(encoder: self))
    }
    
    fileprivate func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("Nested structs are not supported for MySQL")
    }
    
    fileprivate func singleValueContainer() -> SingleValueEncodingContainer {
        return SingleContainer(codingPath: codingPath, encoder: self)
    }
}

fileprivate struct SingleContainer: SingleValueEncodingContainer {
    func encode(_ value: Int) throws {
        try encoder.context.bind(value)
    }
    
    func encode(_ value: Double) throws {
        try encoder.context.bind(value)
    }
    
    func encode(_ value: String) throws {
        try encoder.context.bind(value)
    }
    
    func encode<T: Encodable>(_ value: T) throws {
        if let date = value as? Date {
            try encoder.context.bind(date: date)
        } else {
            try value.encode(to: encoder)
        }
    }
    
    mutating func encode(_ value: Bool) throws {
        fatalError()
        //        try encoder.context.bind(true)
    }
    
    var codingPath = [CodingKey]()
    var encoder: MySQLBindingEncoder
    
    mutating func encodeNil() throws {
        try encoder.context.bindNull()
    }
}

fileprivate struct RowEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol
{
    typealias Key = K
    
    var count: Int
    
    var encoder: MySQLBindingEncoder
    var codingPath: [CodingKey] {
        get { return encoder.codingPath }
    }
    
    public init(encoder: MySQLBindingEncoder) {
        self.encoder = encoder
        self.count = 0
    }
    
    func encode(_ value: Bool, forKey key: K) throws {
        fatalError()
//        try encoder.context.bind(true)
    }
    
    func encode(_ value: Int, forKey key: K) throws {
        try encoder.context.bind(value)
    }
    
    func encode(_ value: Double, forKey key: K) throws {
        try encoder.context.bind(value)
    }
    
    func encode(_ value: String, forKey key: K) throws {
        try encoder.context.bind(value)
    }
    
    func encode<T: Encodable>(_ value: T, forKey key: K) throws {
        if let date = value as? Date {
            try encoder.context.bind(date: date)
        } else {
            try value.encode(to: encoder)
        }
    }
    
    func encodeNil(forKey key: K) throws {
        try encoder.context.bindNull()
    }
    
    func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type, forKey key: K
        ) -> KeyedEncodingContainer<NestedKey> {
        return KeyedEncodingContainer(UnsupportedEncodingContainer(encoder: encoder))
    }
    
    func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        return UnsupportedEncodingContainer<K>(encoder: encoder)
    }
    
    func superEncoder() -> Encoder {
        return encoder
    }
    
    func superEncoder(forKey key: K) -> Encoder {
        return encoder
    }
}

struct UnsupportedNestedEncoding: Error {}
