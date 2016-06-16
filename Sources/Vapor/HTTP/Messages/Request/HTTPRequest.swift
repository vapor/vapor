extension HTTP {
    public final class Request: Message {
        public let headers: Headers
        public let body: Body

        public let method: Method
        public let uri: URI
        public let version: Version
        public internal(set) var parameters: [String: String] = [:]

        public init(method: Method, uri: URI, version: Version = Version(major: 1, minor: 1), headers: Headers = [:], body: Body = .data([])) {
            var headers = headers
            headers.appendHost(for: uri)

            self.method = method
            self.uri = uri
            self.version = version
            self.headers = headers
            self.body = body
        }

        public convenience init(startLineComponents: (BytesSlice, BytesSlice, BytesSlice), headers: Headers, body: HTTP.Body) throws {
            /**
             https://tools.ietf.org/html/rfc2616#section-5.1

             The Request-Line begins with a method token, followed by the
             Request-URI and the protocol version, and ending with CRLF. The
             elements are separated by SP characters. No CR or LF is allowed
             except in the final CRLF sequence.

             Request-Line   = Method SP Request-URI SP HTTP-Version CRLF

             *** [WARNING] ***
             Recipients of an invalid request-line SHOULD respond with either a
             400 (Bad Request) error or a 301 (Moved Permanently) redirect with
             the request-target properly encoded.  A recipient SHOULD NOT attempt
             to autocorrect and then process the request without a redirect, since
             the invalid request-line might be deliberately crafted to bypass
             security filters along the request chain.
             */
            let (methodSlice, uriSlice, httpVersionSlice) = startLineComponents
            let method = Method(uppercased: methodSlice.uppercased)
            // TODO: Consider how to support other schemes here.
            // If on secure socket, defaults https, if not, defaults http
            let uriParser = URIParser(bytes: uriSlice, existingHost: headers["Host"], existingScheme: "http")
            let uri = try uriParser.parse()
            let version = try Version(httpVersionSlice)

            self.init(method: method, uri: uri, version: version, headers: headers, body: body)
        }
    }
}

extension HTTP.Request {
    public var startLine: String {
        // https://tools.ietf.org/html/rfc7230#section-3.1.2
        // status-line = HTTP-version SP status-code SP reason-phrase CRL
        var path = uri.path ?? "/"
        if let q = uri.query where !q.isEmpty {
            path += "?\(q)"
        }
        if let f = uri.fragment where !f.isEmpty {
            path += "#\(f)"
        }
        // Prefix w/ `/` to properly indicate that this we're not using absolute URI.
        // Absolute URIs are deprecated and MUST NOT be generated. (they should be parsed for robustness)
        if !path.hasPrefix("/") {
            path = "/" + path
        }

        let versionLine = "HTTP/\(version.major).\(version.minor)"
        let requestLine = "\(method) \(path) \(versionLine)"
        return requestLine
    }
}

extension HTTP.Request {
    public struct Handler: Responder {
        public typealias Closure = (Request) throws -> Response

        private let closure: Closure

        public init(_ closure: Closure) {
            self.closure = closure
        }

        /**
         Respond to a given request or throw if fails

         - parameter request: request to respond to
         - throws: an error if response fails
         - returns: a response if possible
         */
        public func respond(to request: Request) throws -> Response {
            return try closure(request)
        }
    }
}
