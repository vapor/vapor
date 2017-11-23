public struct ArrayKey: CodingKey {
    public var intValue: Int?
    public var index: Int {
        return intValue!
    }

    public init(index: Int) {
        self.intValue = index
    }

    public init?(intValue: Int) {
        self.intValue = intValue
    }

    public var stringValue: String {
        get { fatalError() }
        set { fatalError() }
    }

    public init?(stringValue: String) {
        fatalError()
    }

}


//extension SingleValueDecodingContainer {
//    public mutating func decode(_ type: Int8.Type) throws -> Int8 {
//        return try Int8(decode(Int.self))
//    }
//
//    public mutating func decode(_ type: Int16.Type) throws -> Int16 {
//        return try Int16(decode(Int.self))
//    }
//
//    public mutating func decode(_ type: Int32.Type) throws -> Int32 {
//        return try Int32(decode(Int.self))
//    }
//
//    public mutating func decode(_ type: Int64.Type) throws -> Int64 {
//        return try Int64(decode(Int.self))
//    }
//
//    public mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
//        return try UInt8(decode(UInt.self))
//    }
//
//    public mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
//        return try UInt16(decode(UInt.self))
//    }
//
//    public mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
//        return try UInt32(decode(UInt.self))
//    }
//
//    public mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
//        return try UInt64(decode(UInt.self))
//    }
//
//    public mutating func decode(_ type: UInt.Type) throws -> UInt {
//        return try UInt(decode(Int.self))
//    }
//
//    public mutating func decode(_ type: Float.Type) throws -> Float {
//        return try Float(decode(Double.self))
//    }
//}

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
