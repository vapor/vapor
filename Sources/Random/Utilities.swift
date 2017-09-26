import Foundation

extension Data {
    /// Converts the data to an unsafe raw pointer.
    internal var rawPointer: UnsafeRawPointer {
        let bytes: UnsafePointer<UInt8> = withUnsafeBytes { $0 }
        return UnsafeRawPointer(bytes)
    }

    internal func cast<T>(to: T.Type = T.self) -> T {
        return rawPointer
            .assumingMemoryBound(to: T.self)
            .pointee
    }
}

extension DataGenerator {
    internal func generate<T>(_ type: T.Type = T.self) throws -> T {
        return try bytes(count: MemoryLayout<T>.size)
            .cast(to: T.self)
    }
}
