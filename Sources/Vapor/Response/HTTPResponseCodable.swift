#warning("TODO: consider renaming to encodeHTTP")

/// Can create an instance of `Self` from a `Response`.
public protocol HTTPResponseDecodable {
    /// Decodes an instance of `Self` from a `HTTPResponse`.
    ///
    /// - parameters:
    ///     - res: `HTTPResponse` to decode.
    ///     - req: The `HTTPRequest` associated with this `HTTPResponse`.
    /// - returns: A `HTTPCodingResult` containing the decoded instance of `Self`.
    static func decode(from res: HTTPResponse, for req: HTTPRequest) throws -> Self
}

/// Can convert `self` to a `Response`.
///
/// Types that conform to this protocol can be returned in route closures.
public protocol HTTPResponseEncodable {
    /// Encodes an instance of `Self` to a `HTTPResponse`.
    ///
    /// - parameters:
    ///     - req: The `HTTPRequest` associated with this `HTTPResponse`.
    /// - returns: An `HTTPResponse`.
    func encode(for req: HTTPRequest) throws -> HTTPResponse
}

/// Can be converted to and from a `Response`.
public typealias HTTPResponseCodable = HTTPResponseDecodable & HTTPResponseEncodable

// MARK: Convenience

extension HTTPResponseEncodable {
    /// Asynchronously encodes `Self` into a `Response`, setting the supplied status and headers.
    ///
    ///     router.post("users") { req -> Future<HTTPResponse> in
    ///         return try req.content
    ///             .decode(User.self)
    ///             .save(on: req)
    ///             .encode(status: .created, for: req)
    ///     }
    ///
    /// - parameters:
    ///     - status: `HTTPStatus` to set on the `Response`.
    ///     - headers: `HTTPHeaders` to merge into the `Response`'s headers.
    /// - returns: Newly encoded `Response`.
    public func encode(status: HTTPStatus, headers: HTTPHeaders = [:], for req: HTTPRequest) throws -> HTTPResponse {
        var res = try self.encode(for: req)
        for (name, value) in headers {
            res.headers.replaceOrAdd(name: name, value: value)
        }
        res.status = status
        return res
    }
}

// MARK: Default Conformances

extension HTTPResponse: HTTPResponseCodable {
    /// See `HTTPResponseCodable`.
    public static func decode(from res: HTTPResponse, for req: HTTPRequest) -> HTTPResponse {
        return res
    }
    
    /// See `HTTPResponseCodable`.
    public func encode(for req: HTTPRequest) -> HTTPResponse {
        return self
    }
}

//extension EventLoopFuture: HTTPResponseEncodable where T: HTTPResponseEncodable {
//    /// See `HTTPResponseEncodable`.
//    public func encode(for req: HTTPRequest) -> HTTPResponse {
//        let future: EventLoopFuture<HTTPResponse> = self.then { encodable in
//            switch encodable.encode(for: req) {
//            case .async(let future): return future
//            case .sync(let response): return self.eventLoop.makeSucceededFuture(result: response)
//            }
//        }
//        return .async(future)
//    }
//}

extension StaticString: HTTPResponseEncodable {
    /// See `HTTPResponseEncodable`.
    public func encode(for req: HTTPRequest) -> HTTPResponse {
        return HTTPResponse(headers: staticStringHeaders, body: self)
    }
}

extension String: HTTPResponseEncodable {
    /// See `HTTPResponseEncodable`.
    public func encode(for req: HTTPRequest) -> HTTPResponse {
        return HTTPResponse(headers: staticStringHeaders, body: self)
    }
}

private let staticStringHeaders: HTTPHeaders = ["content-type": "text/plain; charset=utf-8"]
