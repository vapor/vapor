extension HTTPHeaders {
    public var contentEncoding: HTTPContentEncoding? {
        get {
            self.parseDirectives(name: .contentEncoding).first?.first.flatMap {
                HTTPContentEncoding(directive: $0)
            }
        }
        set {
            if let contentEncoding = newValue {
                self.serializeDirectives([[contentEncoding.directive]], name: .contentEncoding)
            } else {
                self.serializeDirectives([], name: .contentEncoding)
            }
        }
    }
}

public struct HTTPContentEncoding: ExpressibleByStringLiteral, CustomStringConvertible, Equatable {
    public static let gzip: Self = "gzip"
    public static let compress: Self = "compress"
    public static let deflate: Self = "deflate"
    public static let br: Self = "br"
    public static let identity: Self = "identity"
    public static let all: Self = "*"

    public let value: String

    public var description: String {
        self.value
    }

    public init(stringLiteral value: String) {
        self.value = value
    }
}

// MARK: Directives

extension HTTPContentEncoding {
    init?(directive: HTTPHeaders.Directive) {
        guard directive.parameter == nil else {
            /// not a valid header value
            return nil
        }
        self.value = .init(directive.value)
    }

    var directive: HTTPHeaders.Directive {
        .init(value: self.value)
    }
}
