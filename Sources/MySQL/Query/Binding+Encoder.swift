import Core

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
        fatalError("Nested structs are not supported for MySQL")
    }
}

fileprivate final class RowEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol
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
        throw UnsupportedNestedEncoding()
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
