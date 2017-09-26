import Foundation

public protocol DataGenerator {
    /// Get a random array of Bytes
    func bytes(count: Int) throws -> Data
}

// MARK: - Throwing getter methods
extension DataGenerator {
    /// Get a random Int8
    public func makeInt8() throws -> Int8 {
        return try generate()
    }

    /// Get a random UInt8
    public func makeUInt8() throws -> UInt8 {
        return try generate()
    }

    /// Get a random Int16
    public func makeInt16() throws -> Int16 {
        return try generate()
    }

    /// Get a random UInt16
    public func makeUInt16() throws -> UInt16 {
        return try generate()
    }

    /// Get a random Int32
    public func makeInt32() throws -> Int32 {
        return try generate()
    }

    /// Get a random UInt32
    public func makeUInt32() throws -> UInt32 {
        return try generate()
    }

    /// Get a random Int64
    public func makeInt64() throws -> Int64 {
        return try generate()
    }

    /// Get a random UInt64
    public func makeUInt64() throws -> UInt64 {
        return try generate()
    }

    /// Get a random Int
    public func makeInt() throws -> Int {
        return try generate()
    }

    /// Get a random UInt
    public func makeUInt() throws -> UInt {
        return try generate()
    }
}



