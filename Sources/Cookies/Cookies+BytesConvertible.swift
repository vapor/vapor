import Core

extension Cookies: BytesConvertible {
    public init(bytes: Bytes) throws {
        try self.init(bytes, for: .request)
    }

    public func makeBytes() throws -> Bytes {
        return serialize(for: .request).bytes
    }
}
