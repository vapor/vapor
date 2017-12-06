// MARK: Single

extension SingleValueDecodingContainer {
    public mutating func decode(_ type: Int8.Type) throws -> Int8 {
        return try Int8(decode(Int.self))
    }

    public mutating func decode(_ type: Int16.Type) throws -> Int16 {
        return try Int16(decode(Int.self))
    }

    public mutating func decode(_ type: Int32.Type) throws -> Int32 {
        return try Int32(decode(Int.self))
    }

    public mutating func decode(_ type: Int64.Type) throws -> Int64 {
        return try Int64(decode(Int.self))
    }

    public mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        return try UInt8(decode(UInt.self))
    }

    public mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        return try UInt16(decode(UInt.self))
    }

    public mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        return try UInt32(decode(UInt.self))
    }

    public mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        return try UInt64(decode(UInt.self))
    }

    public mutating func decode(_ type: UInt.Type) throws -> UInt {
        return try UInt(decode(Int.self))
    }

    public mutating func decode(_ type: Float.Type) throws -> Float {
        return try Float(decode(Double.self))
    }
}

// MARK: Keyed

extension KeyedDecodingContainerProtocol {
    public mutating func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        return try .init(decode(Int.self, forKey: key))
    }

    public mutating func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        return try .init(decode(Int.self, forKey: key))
    }

    public mutating func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        return try .init(decode(Int.self, forKey: key))
    }

    public mutating func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        return try .init(decode(Int.self, forKey: key))
    }

    public mutating func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        return try .init(decode(Int.self, forKey: key))
    }

    public mutating func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        return try .init(decode(Int.self, forKey: key))
    }

    public mutating func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        return try .init(decode(Int.self, forKey: key))
    }

    public mutating func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        return try .init(decode(Int.self, forKey: key))
    }

    public mutating func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        return try .init(decode(Int.self, forKey: key))
    }

    public mutating func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        return try .init(decode(Double.self, forKey: key))
    }
}

// MARK: Unkeyed

// MARK: Single

extension UnkeyedDecodingContainer {
    public mutating func decode(_ type: Int8.Type) throws -> Int8 {
        return try Int8(decode(Int.self))
    }

    public mutating func decode(_ type: Int16.Type) throws -> Int16 {
        return try Int16(decode(Int.self))
    }

    public mutating func decode(_ type: Int32.Type) throws -> Int32 {
        return try Int32(decode(Int.self))
    }

    public mutating func decode(_ type: Int64.Type) throws -> Int64 {
        return try Int64(decode(Int.self))
    }

    public mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        return try UInt8(decode(UInt.self))
    }

    public mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        return try UInt16(decode(UInt.self))
    }

    public mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        return try UInt32(decode(UInt.self))
    }

    public mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        return try UInt64(decode(UInt.self))
    }

    public mutating func decode(_ type: UInt.Type) throws -> UInt {
        return try UInt(decode(Int.self))
    }

    public mutating func decode(_ type: Float.Type) throws -> Float {
        return try Float(decode(Double.self))
    }
}
