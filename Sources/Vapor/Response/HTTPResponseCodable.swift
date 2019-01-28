#warning("TODO: consider renaming to encodeHTTP")


/// Can convert `self` to a `Response`.
///
/// Types that conform to this protocol can be returned in route closures.
public protocol ResponseEncodable {
    /// Encodes an instance of `Self` to a `HTTPResponse`.
    ///
    /// - parameters:
    ///     - req: The `HTTPRequest` associated with this `HTTPResponse`.
    /// - returns: An `HTTPResponse`.
    func encode(for req: RequestContext) -> EventLoopFuture<HTTPResponse>
}

// MARK: Convenience

extension ResponseEncodable {
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
    public func encode(status: HTTPStatus, headers: HTTPHeaders = [:], for req: RequestContext) -> EventLoopFuture<HTTPResponse> {
        return self.encode(for: req).map { res in
            var res = res
            for (name, value) in headers {
                res.headers.replaceOrAdd(name: name, value: value)
            }
            res.status = status
            return res
        }
    }
}

// MARK: Default Conformances

extension HTTPResponse: ResponseEncodable {
    /// See `HTTPResponseCodable`.
    public func encode(for req: RequestContext) -> EventLoopFuture<HTTPResponse> {
        return req.eventLoop.makeSucceededFuture(self)
    }
}

extension StaticString: ResponseEncodable {
    /// See `HTTPResponseEncodable`.
    public func encode(for req: RequestContext) -> EventLoopFuture<HTTPResponse> {
        let res = HTTPResponse(headers: staticStringHeaders, body: self)
        return req.eventLoop.makeSucceededFuture(res)
    }
}

extension String: ResponseEncodable {
    /// See `HTTPResponseEncodable`.
    public func encode(for req: RequestContext) -> EventLoopFuture<HTTPResponse> {
        let res = HTTPResponse(headers: staticStringHeaders, body: self)
        return req.eventLoop.makeSucceededFuture(res)
    }
}

extension EventLoopFuture: ResponseEncodable where Value: ResponseEncodable {
    /// See `HTTPResponseEncodable`.
    public func encode(for req: RequestContext) -> EventLoopFuture<HTTPResponse> {
        return self.flatMap { t in
            return t.encode(for: req)
        }
    }
}

private let staticStringHeaders: HTTPHeaders = ["content-type": "text/plain; charset=utf-8"]
