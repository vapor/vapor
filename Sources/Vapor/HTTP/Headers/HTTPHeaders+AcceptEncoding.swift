extension HTTPHeaders {
    public struct AcceptEncoding: Equatable {
        public static let gzip: Self = .init(.gzip)
        public static let compress: Self = .init(.compress)
        public static let deflate: Self = .init(.deflate)
        public static let br: Self = .init(.br)
        public static let identity: Self = .init(.identity)
        public static let all: Self = .init(.all)

        /// The `HTTPContentEncoding` in question.
        public var encoding: HTTPContentEncoding

        /// Optional preference for this encoding. Between 0 and 1. 
        public var q: Double?

        public init(_ encoding: HTTPContentEncoding, q: Double? = nil) {
            self.encoding = encoding
            self.q = q
        }
    }

    /// The Accept-Encoding request HTTP header advertises which content encoding, usually a compression algorithm,
    /// the client is able to understand. Using content negotiation, the server selects one of the proposals, uses it and
    /// informs the client of its choice with the Content-Encoding response header.
    public var acceptEncoding: [AcceptEncoding] {
        get {
            self.parseDirectives(name: .acceptEncoding).compactMap {
                AcceptEncoding(directives: $0)
            }
        }
        set {
            self.serializeDirectives(newValue.map { $0.directives }, name: .acceptEncoding)
        }
    }
}

// MARK: Directives

extension HTTPHeaders.AcceptEncoding {
    init?(directives: [HTTPHeaders.Directive]) {
        print(directives)
        switch directives.count {
        case 1:
            guard let encoding = HTTPContentEncoding(directive: directives[0]) else {
                return nil
            }
            self.encoding = encoding
        case 2:
            guard let encoding = HTTPContentEncoding(directive: directives[0]) else {
                return nil
            }
            self.encoding = encoding
            self.q = directives[1].parameter.flatMap(Double.init)
        default:
            return nil
        }
    }

    var directives: [HTTPHeaders.Directive] {
        if let q = self.q {
            return [
                self.encoding.directive,
                .init(value: "q", parameter: q.description)
            ]
        } else {
            return [self.encoding.directive]
        }
    }
}
