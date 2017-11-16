import Foundation
import Bits

/// RandomProtocol implementations can output random sets of data
///
/// [Learn More →](https://docs.vapor.codes/3.0/crypto/random/)
public protocol RandomProtocol {
    /// Get a random array of Data
    func data(count: Int) throws -> Data
}

// MARK: - Throwing getter methods
extension RandomProtocol {
    /// Get a random Int8
    public func makeInt8() throws -> Int8 {
        return Int8(bitPattern: try makeUInt8())
    }

    /// Get a random UInt8
    public func makeUInt8() throws -> UInt8 {
        return try data(count: 1)[0]
    }

    /// Get a random Int16
    public func makeInt16() throws -> Int16 {
        return Int16(bitPattern: try makeUInt16())
    }

    /// Get a random UInt16
    public func makeUInt16() throws -> UInt16 {
        let random = try data(count: 2)
        return random.withUnsafeBytes { (random: BytesPointer) in
            return UnsafeRawPointer(random)
                .assumingMemoryBound(to: UInt16.self)
                .pointee
        }
    }

    /// Get a random Int32
    public func makeInt32() throws -> Int32 {
        return Int32(bitPattern: try makeUInt32())
    }

    /// Get a random UInt32
    public func makeUInt32() throws -> UInt32 {
        let random = try data(count: 4)
        return random.withUnsafeBytes { (random: BytesPointer) in
            return UnsafeRawPointer(random)
                .assumingMemoryBound(to: UInt32.self)
                .pointee
        }
    }

    /// Get a random Int64
    public func makeInt64() throws -> Int64 {
        return Int64(bitPattern: try makeUInt64())
    }

    /// Get a random UInt64
    public func makeUInt64() throws -> UInt64 {
        let random = try data(count: 8)
        return random.withUnsafeBytes { (random: BytesPointer) in
            return UnsafeRawPointer(random)
                .assumingMemoryBound(to: UInt64.self)
                .pointee
        }
    }

    /// Get a random Int
    public func makeInt() throws -> Int {
        return Int(bitPattern: try makeUInt())
    }

    /// Get a random UInt
    public func makeUInt() throws -> UInt {
        let random = try data(count: MemoryLayout<UInt>.size)
        return random.withUnsafeBytes { (random: BytesPointer) in
            return UnsafeRawPointer(random)
                .assumingMemoryBound(to: UInt.self)
                .pointee
        }
    }
}



