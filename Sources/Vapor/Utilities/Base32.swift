import CBase32

extension Data {
    // MARK: Base32

    /// Decodes a base32 encoded `String`.
    public init?(base32Encoded: String) {
        guard let data = base32Encoded.data(using: .utf8) else {
            return nil
        }
        self.init(base32Encoded: data)
    }

    /// Decodes base32 encoded `Data`.
    public init?(base32Encoded: Data) {
        let maxSize = (base32Encoded.count * 5 + 4) / 8
        let result = UnsafeMutablePointer<UInt8>.allocate(capacity: maxSize)
        defer {
            result.deinitialize(count: maxSize)
            result.deallocate()
        }
        let size = base32Encoded.withUnsafeBytes { ptr in
            cbase32_decode(ptr.baseAddress?.assumingMemoryBound(to: UInt8.self), result, numericCast(maxSize))
        }
        self = .init(buffer: UnsafeBufferPointer(start: result, count: numericCast(size)))
    }

    /// Encodes data to a base32 encoded `String`.
    ///
    /// - returns: The base32 encoded string.
    public func base32EncodedString() -> String {
        return String(data: base32EncodedData(), encoding: .utf8)!
    }

    /// Encodes data to base32 encoded `Data`.
    ///
    /// - returns: The base32 encoded data.
    public func base32EncodedData() -> Data {
        let maxSize = (count * 8 + 4) / 5
        let result = UnsafeMutablePointer<UInt8>.allocate(capacity: maxSize)
        defer {
            result.deinitialize(count: maxSize)
            result.deallocate()
        }
        let size = self.withUnsafeBytes { ptr in
            return cbase32_encode(ptr.baseAddress?.assumingMemoryBound(to: UInt8.self), numericCast(count), result, numericCast(maxSize))
        }
        return .init(buffer: UnsafeBufferPointer(start: result, count: numericCast(size)))
    }
}
