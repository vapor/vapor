public final class CodingPathKeyPreEncoder {
    public init() {}
    
    var nested = false
    
    public func keys(for encodable: Encodable) throws -> [[String]] {
        let encoder = _KeyPreEncoder(nested: nested)
        try encodable.encode(to: encoder)
        
        return encoder.keys
    }
}

fileprivate final class _KeyPreEncoder: Encoder {
    fileprivate var userInfo = [CodingUserInfoKey : Any]()
    fileprivate var codingPath = [CodingKey]()
    fileprivate var nested: Bool
    
    var keys = [[String]]()
    
    init(nested: Bool) {
        self.nested = nested
        keys.reserveCapacity(32)
    }
    
    fileprivate func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        return KeyedEncodingContainer(KeyPathKeyedEncodingContainer<Key>(codingPath: codingPath, encoder: self))
    }
    
    fileprivate func unkeyedContainer() -> UnkeyedEncodingContainer {
        return KeyPathUnkeyedEncodingContainer(count: 0, codingPath: codingPath, encoder: self)
    }
    
    fileprivate func singleValueContainer() -> SingleValueEncodingContainer {
        return KeyPathSingleValueEncodingContainer(codingPath: self.codingPath)
    }
}

fileprivate struct KeyPathSingleValueEncodingContainer: SingleValueEncodingContainer {
    var codingPath: [CodingKey]
    
    mutating func encodeNil() throws {}
    mutating func encode(_ value: Int) throws {}
    mutating func encode(_ value: Bool) throws {}
    mutating func encode<T>(_ value: T) throws where T : Encodable {}
    mutating func encode(_ value: String) throws {}
    mutating func encode(_ value: Double) throws {}
}

fileprivate struct KeyPathKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    var codingPath: [CodingKey]
    var stringPath: [String]
    var encoder: _KeyPreEncoder
    
    init(codingPath: [CodingKey], encoder: _KeyPreEncoder) {
        self.codingPath = codingPath
        self.encoder = encoder
        
        self.stringPath = codingPath.map { $0.stringValue }
    }
    
    mutating func encodeNil(forKey key: K) throws {
        encoder.keys.append(stringPath + [key.stringValue])
    }
    
    mutating func encode<T>(_ value: T, forKey key: K) throws where T : Encodable {
        encoder.keys.append(stringPath + [key.stringValue])
    }
    
    mutating func encode(_ value: String, forKey key: K) throws {
        encoder.keys.append(stringPath + [key.stringValue])
    }
    
    mutating func encode(_ value: Double, forKey key: K) throws {
        encoder.keys.append(stringPath + [key.stringValue])
    }
    
    mutating func encode(_ value: Int, forKey key: K) throws {
        encoder.keys.append(stringPath + [key.stringValue])
    }
    
    mutating func encode(_ value: Bool, forKey key: K) throws {
        encoder.keys.append(stringPath + [key.stringValue])
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        encoder.keys.append(stringPath + [key.stringValue])
        return KeyedEncodingContainer(KeyPathKeyedEncodingContainer<NestedKey>(codingPath: codingPath, encoder: encoder))
    }
    
    mutating func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        encoder.keys.append(stringPath + [key.stringValue])
        return KeyPathUnkeyedEncodingContainer(count: 0, codingPath: codingPath, encoder: encoder)
    }
    
    mutating func superEncoder() -> Encoder {
        return encoder
    }
    
    mutating func superEncoder(forKey key: K) -> Encoder {
        return encoder
    }
    
    typealias Key = K
}

fileprivate struct KeyPathUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    var count: Int = 0
    
    var codingPath: [CodingKey]
    var encoder: _KeyPreEncoder
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        return KeyedEncodingContainer(KeyPathKeyedEncodingContainer(codingPath: codingPath, encoder: encoder))
    }
    
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        return KeyPathUnkeyedEncodingContainer(count: count, codingPath: codingPath, encoder: encoder)
    }
    
    mutating func superEncoder() -> Encoder {
        return encoder
    }
    
    mutating func encodeNil() throws {}
    mutating func encode(_ value: Int) throws {}
    mutating func encode(_ value: Bool) throws {}
    mutating func encode<T>(_ value: T) throws where T : Encodable {}
    mutating func encode(_ value: String) throws {}
    mutating func encode(_ value: Double) throws {}
}
