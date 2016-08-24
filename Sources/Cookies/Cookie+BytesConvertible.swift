import Core

extension Cookie: BytesConvertible {
    public init(bytes: Bytes) throws {
        try self.init(bytes)
    }

    public func makeBytes() -> Bytes {
        return serialize().bytes
    }
}
