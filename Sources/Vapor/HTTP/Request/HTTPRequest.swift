//public final class HTTPRequest: HTTPMessage {
//    // TODO: internal set for head request in application, serializer should change it, avoid exposing to end user
//    public internal(set) var method: Method
//
//    public var uri: URI
//    public let version: Version
//
//    public internal(set) var parameters: [String: String] = [:]
//
//    public convenience init(method: Method, path: String, host: String = "*", version: Version = Version(major: 1, minor: 1), headers: Headers = [:], body: HTTPBody = .data([])) throws {
//        let path = path.hasPrefix("/") ? path : "/" + path
//        var uri = try URI(path)
//        uri.host = host
//        self.init(method: method, uri: uri, version: version, headers: headers, body: body)
//    }
//
//    public convenience init(method: Method, uri: String, version: Version = Version(major: 1, minor: 1), headers: Headers = [:], body: HTTPBody = .data([])) throws {
//        let uri = try URI(uri)
//        self.init(method: method, uri: uri, version: version, headers: headers, body: body)
//    }
//
//    public init(method: Method,
//                uri: URI,
//                version: Version = Version(major: 1, minor: 1),
//                headers: Headers = [:],
//                body: HTTPBody = .data([])) {
//        var headers = headers
//        headers.appendHost(for: uri)
//
//        self.method = method
//        self.uri = uri
//        self.version = version
//
//        // https://tools.ietf.org/html/rfc7230#section-3.1.2
//        // status-line = HTTP-version SP status-code SP reason-phrase CRL
//        var path = uri.path ?? "/"
//        if let q = uri.query where !q.isEmpty {
//            path += "?\(q)"
//        }
//        if let f = uri.fragment where !f.isEmpty {
//            path += "#\(f)"
//        }
//        // Prefix w/ `/` to properly indicate that this we're not using absolute URI.
//        // Absolute URIs are deprecated and MUST NOT be generated. (they should be parsed for robustness)
//        if !path.hasPrefix("/") {
//            path = "/" + path
//        }
//
//        let versionLine = "HTTP/\(version.major).\(version.minor)"
//        let requestLine = "\(method) \(path) \(versionLine)"
//        super.init(startLine: requestLine, headers: headers, body: body)
//
//        setupContent()
//    }
//
//    public convenience required init(startLineComponents: (BytesSlice, BytesSlice, BytesSlice), headers: Headers, body: HTTPBody) throws {
//        /**
//            https://tools.ietf.org/html/rfc2616#section-5.1
//
//            The Request-Line begins with a method token, followed by the
//            Request-URI and the protocol version, and ending with CRLF. The
//            elements are separated by SP characters. No CR or LF is allowed
//            except in the final CRLF sequence.
//
//            Request-Line   = Method SP Request-URI SP HTTP-Version CRLF
//
//            *** [WARNING] ***
//            Recipients of an invalid request-line SHOULD respond with either a
//            400 (Bad Request) error or a 301 (Moved Permanently) redirect with
//            the request-target properly encoded.  A recipient SHOULD NOT attempt
//            to autocorrect and then process the request without a redirect, since
//            the invalid request-line might be deliberately crafted to bypass
//            security filters along the request chain.
//        */
//        let (methodSlice, uriSlice, httpVersionSlice) = startLineComponents
//        let method = Method(uppercased: methodSlice.uppercased)
//        let uriParser = URIParser(bytes: uriSlice.array, existingHost: headers["Host"])
//        var uri = try uriParser.parse()
//        uri.scheme = uri.scheme.isNilOrEmpty ? "http" : uri.scheme
//        let version = try Version(httpVersionSlice)
//
//        self.init(method: method, uri: uri, version: version, headers: headers, body: body)
//    }
//
//    private func setupContent() {
//        self.data.append(self.query)
//        self.data.append(self.json)
//        self.data.append(self.formURLEncoded)
//        self.data.append { [weak self] indexes in
//            guard let first = indexes.first else { return nil }
//            if let string = first as? String {
//                return self?.multipart?[string]
//            } else if let int = first as? Int {
//                return self?.multipart?["\(int)"]
//            } else {
//                return nil
//            }
//        }
//    }
//}
//
//extension HTTPRequest {
//    public struct Handler: Responder {
//        public typealias Closure = (Request) throws -> Response
//
//        private let closure: Closure
//
//        public init(_ closure: Closure) {
//            self.closure = closure
//        }
//
//        /**
//            Respond to a given request or throw if fails
//
//            - parameter request: request to respond to
//            - throws: an error if response fails
//            - returns: a response if possible
//        */
//        public func respond(to request: Request) throws -> Response {
//            return try closure(request)
//        }
//    }
//}
