public enum HTTPBody {
    case data(Bytes)
    case chunked((ChunkStream) throws -> Void)
}

public protocol HTTPBodyConvertible {
    func makeBody() -> HTTPBody
}

extension String: HTTPBodyConvertible {
    public func makeBody() -> HTTPBody {
        return HTTPBody(self)
    }
}

extension JSON: HTTPBodyConvertible {
    public func makeBody() -> HTTPBody {
        return HTTPBody(self)
    }
}

extension HTTPBody {
    public var bytes: Bytes? {
        guard case let .data(bytes) = self else { return nil }
        return bytes
    }
}

extension HTTPBody {
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

extension HTTPBody {
    public init(_ json: JSON) {
        let bytes = json.serialize().utf8
        self.init(bytes)
    }
}

extension HTTPBody: ArrayLiteralConvertible {
    /// Creates an instance initialized with the given elements.
    public init(arrayLiteral elements: Byte...) {
        self.init(elements)
    }
}
