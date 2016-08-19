import Core

extension Cookies: BytesConvertible {
    public init(bytes: Bytes) throws {
        try self.init(bytes)
    }

    public func makeBytes() throws -> Bytes {
        return serialize(for: .request).bytes
    }
}
