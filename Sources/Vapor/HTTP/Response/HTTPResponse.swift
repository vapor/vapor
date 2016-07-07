//import S4
//
//// So common we simplify it
//
//public final class HTTPResponse: HTTPMessage {
//    public let version: Version
//    public let status: Status
//
//    // MARK: Post Serialization
//
//    public var onComplete: ((Engine.Stream) throws -> Void)?
//
//    public init(
//        version: Version = Version(major: 1, minor: 1),
//        status: Status = .ok,
//        headers: Headers = [:],
//        body: HTTPBody = .data([])
//    ) {
//        self.version = version
//        self.status = status
//
//
//        let statusLine = "HTTP/\(version.major).\(version.minor) \(status.statusCode) \(status.reasonPhrase)"
//        super.init(startLine: statusLine, headers: headers, body: body)
//
//        self.data.append(self.json)
//    }
//
//    public convenience required init(
//        startLineComponents: (BytesSlice, BytesSlice, BytesSlice),
//        headers: Headers,
//        body: HTTPBody
//    ) throws {
//        let (httpVersionSlice, statusCodeSlice, reasonPhrase) = startLineComponents
//        // TODO: Right now in Status, if you pass reason phrase, it automatically overrides status code. Try to use reason phrase
//        // keeping weirdness here to help reminder and silence warnings
//        _ = reasonPhrase
//
//        let version = try Version(httpVersionSlice)
//        guard let statusCode = Int(statusCodeSlice.string) else {
//            throw HTTPMessageError.invalidStartLine
//        }
//        // TODO: If we pass status reason phrase, it overrides status, adjust so that's not a thing
//        let status = Status(statusCode: statusCode)
//
//        self.init(version: version, status: status, headers: headers, body: body)
//    }
//}
//
//extension HTTPResponse {
//    /*
//        Creates a redirect response.
//     
//        Set permanently to 'true' to allow caching to automatically redirect from browsers.
//        Defaulting to non-permanent to prevent unexpected caching.
//    */
//    public convenience init(headers: Headers = [:], redirect location: String, permanently: Bool = false) {
//        var headers = headers
//        headers["Location"] = location
//        // .found == 302 and is commonly used for temporarily moved
//        let status: Status = permanently ? .movedPermanently : .found
//        self.init(status: status, headers: headers)
//    }
//}
//
//extension HTTPResponse {
//    /*
//        Creates a Response with a body of Bytes.
//    */
//    public convenience init<
//        S: Sequence where S.Iterator.Element == Byte
//    >(version: Version = Version(major: 1, minor: 1), status: Status = .ok, headers: Headers = [:], body: S) {
//        let body = HTTPBody(body)
//        self.init(version: version, status: status, headers: headers, body: body)
//    }
//}
//
//
//
//extension HTTPResponse {
//    /*
//        Creates a Response with a HTTPBodyRepresentable Body
//    */
//    public convenience init(
//        version: Version = Version(major: 1, minor: 1),
//        status: Status = .ok,
//        headers: Headers = [:],
//        body: HTTPBodyRepresentable
//    ) {
//        let body = body.makeBody()
//        self.init(version: version, status: status, headers: headers, body: body)
//    }
//}
