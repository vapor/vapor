public struct UnsupportedEncodingError: Error {}

public final class UnsupportedEncodingContainer<K: CodingKey> {
    let encoder: Encoder
    public init(encoder: Encoder) {
        self.encoder = encoder
    }
}

// MARK: Single

extension UnsupportedEncodingContainer: SingleValueEncodingContainer {
    public var codingPath: [CodingKey] {
        return []
    }
    
    public func encodeNil() throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: Bool) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: Int) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: Int8) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: Int16) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: Int32) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: Int64) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: UInt) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: UInt8) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: UInt16) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: UInt32) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: UInt64) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: Float) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: Double) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: String) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode<T: Encodable>(_ value: T) throws {
        throw UnsupportedEncodingError()
    }
}

// MARK: Unkeyed

extension UnsupportedEncodingContainer: UnkeyedEncodingContainer {
    public var count: Int {
        return 0
    }
    
    public func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        return KeyedEncodingContainer(UnsupportedEncodingContainer<NestedKey>(encoder: encoder))
    }
    
    public func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        return self
    }
    
    public func superEncoder() -> Encoder {
        return encoder
    }
}

// MARK: Keyed

extension UnsupportedEncodingContainer: KeyedEncodingContainerProtocol {
    public typealias Key = K
    
    public func encodeNil(forKey key: Key) throws {
        throw UnsupportedEncodingError()
    }
    
    public func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        return KeyedEncodingContainer(UnsupportedEncodingContainer<NestedKey>(encoder: encoder))
    }
    
    public func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        return self
    }
    
    public func superEncoder(forKey key: Key) -> Encoder {
        return encoder
    }
    
    public func encode(_ value: Bool, forKey key: Key) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: Int, forKey key: Key) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: Int8, forKey key: Key) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: Int16, forKey key: Key) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: Int32, forKey key: Key) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: Int64, forKey key: Key) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: UInt, forKey key: Key) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: UInt8, forKey key: Key) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: UInt16, forKey key: Key) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: UInt32, forKey key: Key) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: UInt64, forKey key: Key) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: Float, forKey key: Key) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: Double, forKey key: Key) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode(_ value: String, forKey key: Key) throws {
        throw UnsupportedEncodingError()
    }
    
    public func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        throw UnsupportedEncodingError()
    }
}
