/// Less verbose typealias for `HTTPResponseStatus`.
public typealias HTTPStatus = HTTPResponseStatus

extension HTTPStatus {
    /// The class of an HTTP status code (i.e., 1xx, 2xx, etc).
    public enum Class: Equatable {
        /// The 1xx (Informational) class of status code indicates an interim
        /// response for communicating connection status or request progress
        /// prior to completing the requested action and sending a final
        /// response.
        case informational

        /// The 2xx (Successful) class of status code indicates that the client's
        /// request was successfully received, understood, and accepted.
        case successful

        /// The 3xx (Redirection) class of status code indicates that further
        /// action needs to be taken by the user agent in order to fulfill the
        /// request.
        case redirection

        ///  The 4xx (Client Error) class of status code indicates that the client
        /// seems to have erred.
        case clientError

        /// The 5xx (Server Error) class of status code indicates that the server
        /// is aware that it has erred or is incapable of performing the
        /// requested method.
        case serverError
    }

    /// Returns the status code's class (i.e., 1xx, 2xx, etc).
    /// See `HTTPStatus.Class` for more information.
    public var `class`: Class? {
        switch self.code {
        case 100..<200:
            return .informational
        case 200..<300:
            return .successful
        case 300..<400:
            return .redirection
        case 400..<500:
            return .clientError
        case 500..<600:
            return .serverError
        default:
            return nil
        }
    }
}

extension HTTPStatus: ResponseEncodable {
    /// See `ResponseEncodable`.
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let response = Response(status: self)
        return request.eventLoop.makeSucceededFuture(response)
    }
}

extension HTTPStatus: Codable {
    public init(from decoder: Decoder) throws {
        let code = try decoder.singleValueContainer().decode(Int.self)
        self = .init(statusCode: code)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.code)
    }
}
