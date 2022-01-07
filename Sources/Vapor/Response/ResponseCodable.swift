/// Can convert `self` to a `Response`.
///
/// Types that conform to this protocol can be returned in route closures.
public protocol ResponseEncodable {
    /// Encodes an instance of `Self` to a `Response`.
    ///
    /// - parameters:
    ///     - for: The `Request` associated with this `Response`.
    /// - returns: A `Response`.
    func encodeResponse(for request: Request) -> EventLoopFuture<Response>
}

/// Can convert `Request` to a `Self`.
///
/// Types that conform to this protocol can decode requests to their type.
public protocol RequestDecodable {
    /// Decodes an instance of `Request` to a `Self`.
    ///
    /// - parameters:
    ///     - request: The `Request` to be decoded.
    /// - returns: An asynchronous `Self`.
    static func decodeRequest(_ request: Request) -> EventLoopFuture<Self>
}

extension Request: RequestDecodable {
    public static func decodeRequest(_ request: Request) -> EventLoopFuture<Request> {
        return request.eventLoop.makeSucceededFuture(request)
    }
}

// MARK: Convenience

extension ResponseEncodable {
    /// Asynchronously encodes `Self` into a `Response`, setting the supplied status and headers.
    ///
    ///     router.post("users") { req -> EventLoopFuture<Response> in
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
    public func encodeResponse(status: HTTPStatus, headers: HTTPHeaders = [:], for request: Request) -> EventLoopFuture<Response> {
        return self.encodeResponse(for: request).map { response in
            for (name, value) in headers {
                response.headers.replaceOrAdd(name: name, value: value)
            }
            response.status = status
            return response
        }
    }
}

// MARK: Default Conformances

extension Response: ResponseEncodable {
    // See `ResponseEncodable`.
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        return request.eventLoop.makeSucceededFuture(self)
    }
}

extension StaticString: ResponseEncodable {
    // See `ResponseEncodable`.
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let res = Response(headers: staticStringHeaders, body: .init(staticString: self))
        return request.eventLoop.makeSucceededFuture(res)
    }
}

extension String: ResponseEncodable {
    // See `ResponseEncodable`.
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let res = Response(headers: staticStringHeaders, body: .init(string: self))
        return request.eventLoop.makeSucceededFuture(res)
    }
}

extension EventLoopFuture: ResponseEncodable where Value: ResponseEncodable {
    // See `ResponseEncodable`.
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        return self.flatMap { t in
            return t.encodeResponse(for: request)
        }
    }
}

internal let staticStringHeaders: HTTPHeaders = ["content-type": "text/plain; charset=utf-8"]
