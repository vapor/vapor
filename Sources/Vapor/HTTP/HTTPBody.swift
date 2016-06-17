public typealias Body = HTTP.Body

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

extension HTTP.Body {
    public init(_ str: String) {
        self.init(str.utf8)
    }
    public init<S: Sequence where S.Iterator.Element == Byte>(_ s: S) {
        self = .data(s.array)
    }
    public init(_ chunker: (ChunkStream) throws -> Void) {
        self = .chunked(chunker)
    }
}

extension HTTP.Body {
    public init(_ json: JSON) {
        let bytes = json.serialize().utf8
        self.init(bytes)
    }
}

extension HTTP.Body: ArrayLiteralConvertible {
    /// Creates an instance initialized with the given elements.
    public init(arrayLiteral elements: Byte...) {
        self.init(elements)
    }
}
