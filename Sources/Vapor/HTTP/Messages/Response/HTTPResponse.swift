import S4

public typealias Response = HTTP.Response

extension HTTP {
    public final class Response: Message {
        public var headers: Headers
        // Settable for HEAD request -- evaluate alternatives -- Perhaps serializer should handle it.
        // must NOT be exposed public because changing body will break behavior most of time
        public internal(set) var body: HTTP.Body

        public let version: Version
        public let status: Status

        // MARK: Extensibility

        public var storage: [String: Any] = [:]
        public private(set) lazy var data: Content = Content(self)

        // MARK: Post Serialization

        public var onComplete: ((Stream) throws -> Void)?

        public init(version: Version = Version(major: 1, minor: 1), status: Status = .ok, headers: Headers = [:], body: Body = .data([])) {
            self.version = version
            self.status = status
            self.headers = headers
            self.body = body

            self.data.append(self.json)
        }

        // TODO: Establish appropriate cookie handling? Should it be built off of headers?
        //        public let cookies: Any! = nil
        public convenience init(startLineComponents: (BytesSlice, BytesSlice, BytesSlice), headers: Headers, body: HTTP.Body) throws {
            let (httpVersionSlice, statusCodeSlice, reasonPhrase) = startLineComponents
            // TODO: Right now in Status, if you pass reason phrase, it automatically overrides status code. Try to use reason phrase
            // keeping weirdness here to help reminder and silence warnings
            _ = reasonPhrase

            let version = try Version(httpVersionSlice)
            guard let statusCode = Int(statusCodeSlice.string) else { fatalError("throw real error") }
            // TODO: If we pass status reason phrase, it overrides status, adjust so that's not a thing
            let status = Status(statusCode: statusCode)

            self.init(version: version, status: status, headers: headers, body: body)
        }
    }
}

extension HTTP.Response {
    public var startLine: String {
        return "HTTP/\(version.major).\(version.minor) \(status.statusCode) \(status.reasonPhrase)"
    }
}

extension HTTP.Response {
    public convenience init(error: String) {
        // TODO: Replicate original behavior!!
        let body = error.utf8.array
        self.init(status: .internalServerError, body: .data(body))
    }
}

extension HTTP.Response {
    /**
         Send chunked data with the
         `Transfer-Encoding: Chunked` header.

         Chunked uses the Transfer-Encoding HTTP header in
         place of the Content-Length header.

         https://en.wikipedia.org/wiki/Chunked_transfer_encoding
    */
    public convenience init(status: Status = .ok, headers: Headers = [:], chunked closure: ((ChunkStream) throws -> Void)) {
        var headers = headers
        headers.setTransferEncodingChunked()
        self.init(status: status, headers: headers, body: .chunked(closure))
    }
}

extension HTTP.Response {
    /**
         Convenience Initializer

         - parameter status: the http status
         - parameter json: any value that will be attempted to be serialized as json.  Use 'Json' for more complex objects
     */
    public convenience init(status: Status, json: JSON) {
        let headers: Headers = [
            "Content-Type": "application/json; charset=utf-8"
        ]
        self.init(status: status, headers: headers, body: HTTP.Body(json))
    }
}

extension HTTP.Response {
    /*
        Creates a redirect response with
        the 301 Status an `Location` header.
    */
    public convenience init(headers: Headers = [:], redirect location: String) {
        var headers = headers
        headers["Location"] = location
        self.init(status: .movedPermanently, headers: headers)
    }
}

extension HTTP.Response {
    /*
     Creates a redirect response with
     the 301 Status an `Location` header.
     */
    public convenience init<S: Sequence where S.Iterator.Element == Byte>(version: Version = Version(major: 1, minor: 1), status: Status = .ok, headers: Headers = [:], body: S) {
        let body = Body(body)
        self.init(version: version, status: status, headers: headers, body: body)
    }
}
