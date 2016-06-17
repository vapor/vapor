public typealias Request = HTTP.Request

extension HTTP {
    public final class Request: Message {
        public var headers: Headers
        public let body: Body

        // TODO: internal set for head request in application, serializer should change it, avoid exposing to end user
        public internal(set) var method: Method
        
        public let uri: URI
        public let version: Version

        public internal(set) var parameters: [String: String] = [:]

        // TODO: Extensibility

        public var storage: [String: Any] = [:]
        public private(set) lazy var data: Content = Content(self)

        public convenience init(method: Method, path: String, host: String = "*", version: Version = Version(major: 1, minor: 1), headers: Headers = [:], body: Body = .data([])) throws {
            let path = path.hasPrefix("/") ? path : "/" + path
            var uri = try URI(path)
            uri.host = host
            self.init(method: method, uri: uri, version: version, headers: headers, body: body)
        }

        public convenience init(method: Method, uri: String, version: Version = Version(major: 1, minor: 1), headers: Headers = [:], body: Body = .data([])) throws {
            let uri = try URI(uri)
            self.init(method: method, uri: uri, version: version, headers: headers, body: body)
        }

        public init(method: Method, uri: URI, version: Version = Version(major: 1, minor: 1), headers: Headers = [:], body: Body = .data([])) {
            var headers = headers
            headers.appendHost(for: uri)

            self.method = method
            self.uri = uri
            self.version = version
            self.headers = headers
            self.body = body

            self.data.append(self.query)
            self.data.append(self.json)
            self.data.append(self.formURLEncoded)
            self.data.append { [weak self] indexes in
                guard let first = indexes.first else { return nil }
                if let string = first as? String {
                    return self?.multipart?[string]
                } else if let int = first as? Int {
                    return self?.multipart?["\(int)"]
                } else {
                    return nil
                }
            }
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

}

extension HTTP.Request {
    public struct Handler: HTTP.Responder {
        public typealias Closure = (HTTP.Request) throws -> HTTP.Response

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
        public func respond(to request: HTTP.Request) throws -> HTTP.Response {
            return try closure(request)
        }
    }
}

// TODO: WebSockets

public enum WebSocketRequestFormat: ErrorProtocol {
    case missingSecKeyHeader
    case missingUpgradeHeader
    case missingConnectionHeader
    case invalidOrUnsupportedVersion
}

extension HTTP.Request {
    /**
     Upgrades the request to a WebSocket connection
     WebSocket connection to provide two way information
     transfer between the client and the server.
     */
    public func upgradeToWebSocket(
        supportedProtocols: ([String]) -> [String] = { $0 },
        body: (ws: WebSocket) throws -> Void) throws -> HTTP.Response {
        guard let requestKey = headers.secWebSocketKey else {
            throw WebSocketRequestFormat.missingSecKeyHeader
        }
        guard headers.upgrade == "websocket" else {
            throw WebSocketRequestFormat.missingUpgradeHeader
        }
        guard headers.connection?.range(of: "Upgrade") != nil else {
            throw WebSocketRequestFormat.missingConnectionHeader
        }

        // TODO: Find other versions and see if we can support -- this is version mentioned in RFC
        guard let version = headers.secWebSocketVersion where version == "13" else {
            throw WebSocketRequestFormat.invalidOrUnsupportedVersion
        }

        var responseHeaders: Headers = [:]
        responseHeaders.connection = "Upgrade"
        responseHeaders.upgrade = "websocket"
        responseHeaders.secWebSocketAccept = WebSocket.exchange(requestKey: requestKey)
        responseHeaders.secWebSocketVersion = version

        if let passedProtocols = headers.secWebProtocol {
            responseHeaders.secWebProtocol = supportedProtocols(passedProtocols)
        }

        let response = HTTP.Response(status: .switchingProtocols, headers: responseHeaders)
        response.onComplete = { stream in
            let ws = WebSocket(stream)
            try body(ws: ws)
            try ws.listen()
        }
        return response
        
    }
}

extension HTTP.Request {
    /// Query data from the URI path
    public var query: StructuredData? {
        if let existing = storage["query"] {
            return existing as? StructuredData
        } else if let queryRaw = uri.query {
            let query = StructuredData(formURLEncoded: queryRaw.data)
            storage["query"] = query
            return query
        } else {
            return nil
        }
    }
}

extension HTTP.Request {
    public var cookies: Cookies {
        get {
            guard let cookies = storage["cookies"] as? Cookies else {
                return []
            }

            return cookies
        }
        set(data) {
            storage["cookies"] = data
        }
    }
}

extension HTTP.Request {
    /// form url encoded encoded request data
    public var formURLEncoded: StructuredData? {
        get {
            if let existing = storage["form-urlencoded"] as? StructuredData {
                return existing
            } else if let type = headers["Content-Type"] where type.contains("application/x-www-form-urlencoded") {
                guard case let .data(body) = body else { return nil }
                let formURLEncoded = StructuredData(formURLEncoded: Data(body))
                storage["form-urlencoded"] = formURLEncoded
                return formURLEncoded
            } else {
                return nil
            }
        }
        set(data) {
            storage["form-urlencoded"] = data
        }
    }
}

extension HTTP.Request {
    /**
     Multipart encoded request data sent using
     the `multipart/form-data...` header.

     Used by web browsers to send files.
     */
    public var multipart: [String: Multipart]? {
        if let existing = storage["multipart"] as? [String: Multipart]? {
            return existing
        } else if let type = headers["Content-Type"] where type.contains("multipart/form-data") {
            guard case let .data(body) = body else { return nil }
            guard let boundary = try? Multipart.parseBoundary(contentType: type) else { return nil }
            let multipart = Multipart.parse(Data(body), boundary: boundary)
            storage["multipart"] = multipart
            return multipart
        } else {
            return nil
        }
    }
}

extension HTTP.Request {
    public var keepAlive: Bool {
        // HTTP 1.1 defaults to true unless explicitly passed `Connection: close`
        guard let value = headers["Connection"] else { return true }
        // TODO: Decide on if 'contains' is better, test linux version
        return !value.contains("close")
    }
}

extension HTTP.Request {
    /// Server stored information related from session cookie.
    public var session: Session? {
        get {
            return storage["session"] as? Session
        }
        set(session) {
            storage["session"] = session
        }
    }
}
