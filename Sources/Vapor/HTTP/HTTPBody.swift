extension HTTP {
    public enum Body {
        case data(Bytes)
        case chunked((ChunkStream) throws -> Void)
    }
}

extension HTTP.Body {
    public var bytes: Bytes? {
        guard case let .data(bytes) = self else { return nil }
        return bytes
    }
}

