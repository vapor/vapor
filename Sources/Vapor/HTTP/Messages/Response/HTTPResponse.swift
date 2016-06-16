import S4

extension HTTP {
    public final class Response: Message {
        public internal(set) var headers: Headers
        // Settable for HEAD request -- evaluate alternatives
        public internal(set) var body: HTTP.Body

        public let version: Version
        public let status: Status

        public var onComplete: ((Stream) throws -> Void)?

        public var storage: [String: Any] = [:]

        public init(version: Version = Version(major: 1, minor: 1), status: Status = .ok, headers: Headers = [:], body: Body = .data([])) {
            self.version = version
            self.status = status
            self.headers = headers
            self.body = body
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