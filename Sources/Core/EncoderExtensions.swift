// MARK: Single

extension SingleValueEncodingContainer {
    public mutating func encode(_ value: Int8) throws {
        try encode(Int(value))
    }

    public mutating func encode(_ value: Int16) throws {
        try encode(Int(value))
    }

    public mutating func encode(_ value: Int32) throws {
        try encode(Int(value))
    }

    public mutating func encode(_ value: Int64) throws {
        try encode(Int(value))
    }

    public mutating func encode(_ value: UInt) throws {
        try encode(Int(value))
    }

    public mutating func encode(_ value: UInt8) throws {
        try encode(Int(value))
    }

    public mutating func encode(_ value: UInt16) throws {
        try encode(Int(value))
    }

    public mutating func encode(_ value: UInt32) throws {
        try encode(Int(value))
    }

    public mutating func encode(_ value: UInt64) throws {
        try encode(Int(value))
    }

    public mutating func encode(_ value: Float) throws {
        try encode(Double(value))
    }
}

// MARK: Keyed

extension KeyedEncodingContainerProtocol {
    public mutating func encode(_ value: Int8, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }

    public mutating func encode(_ value: Int16, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }

    public mutating func encode(_ value: Int32, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }

    public mutating func encode(_ value: Int64, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }

    public mutating func encode(_ value: UInt, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }

    public mutating func encode(_ value: UInt8, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }

    public mutating func encode(_ value: UInt16, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }

    public mutating func encode(_ value: UInt32, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }

    public mutating func encode(_ value: UInt64, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }

    public mutating func encode(_ value: Float, forKey key: Key) throws {
        try encode(Double(value), forKey: key)
    }
}

// MARK: Unkeyed

extension UnkeyedEncodingContainer {
    public mutating func encode(_ value: Int8) throws {
        try encode(Int(value))
    }

    public mutating func encode(_ value: Int16) throws {
        try encode(Int(value))
    }

    public mutating func encode(_ value: Int32) throws {
        try encode(Int(value))
    }

    public mutating func encode(_ value: Int64) throws {
        try encode(Int(value))
    }

    public mutating func encode(_ value: UInt) throws {
        try encode(Int(value))
    }

    public mutating func encode(_ value: UInt8) throws {
        try encode(Int(value))
    }

    public mutating func encode(_ value: UInt16) throws {
        try encode(Int(value))
    }

    public mutating func encode(_ value: UInt32) throws {
        try encode(Int(value))
    }

    public mutating func encode(_ value: UInt64) throws {
        try encode(Int(value))
    }

    public mutating func encode(_ value: Float) throws {
        try encode(Double(value))
    }
}
