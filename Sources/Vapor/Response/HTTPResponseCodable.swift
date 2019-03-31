#warning("TODO: consider renaming to encodeHTTP")
#warning("TODO: consider merging with Responder protocol")

/// Can convert `self` to a `Response`.
///
/// Types that conform to this protocol can be returned in route closures.
public protocol ResponseEncodable {
    /// Encodes an instance of `Self` to a `HTTPResponse`.
    ///
    /// - parameters:
    ///     - req: The `HTTPRequest` associated with this `HTTPResponse`.
    /// - returns: An `HTTPResponse`.
    func encodeResponse(for req: HTTPRequest, using ctx: Context) -> EventLoopFuture<HTTPResponse>
}

public protocol RequestDecodable {
    static func decodeRequest(_ req: HTTPRequest, using ctx: Context) -> EventLoopFuture<Self>
}

extension HTTPRequest: RequestDecodable {
    public static func decodeRequest(_ req: HTTPRequest, using ctx: Context) -> EventLoopFuture<HTTPRequest> {
        return ctx.eventLoop.makeSucceededFuture(req)
    }
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
    public func encodeResponse(
        status: HTTPStatus,
        headers: HTTPHeaders = [:],
        for req: HTTPRequest,
        using ctx: Context
    ) -> EventLoopFuture<HTTPResponse> {
        return self.encodeResponse(for: req, using: ctx).map { res in
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
    public func encodeResponse(for req: HTTPRequest, using ctx: Context) -> EventLoopFuture<HTTPResponse> {
        return ctx.eventLoop.makeSucceededFuture(self)
    }
}

extension StaticString: ResponseEncodable {
    /// See `HTTPResponseEncodable`.
    public func encodeResponse(for req: HTTPRequest, using ctx: Context) -> EventLoopFuture<HTTPResponse> {
        let res = HTTPResponse(headers: staticStringHeaders, body: .init(staticString: self))
        return ctx.eventLoop.makeSucceededFuture(res)
    }
}

extension String: ResponseEncodable {
    /// See `HTTPResponseEncodable`.
    public func encodeResponse(for req: HTTPRequest, using ctx: Context) -> EventLoopFuture<HTTPResponse> {
        let res = HTTPResponse(headers: staticStringHeaders, body: .init(string: self))
        return ctx.eventLoop.makeSucceededFuture(res)
    }
}

extension EventLoopFuture: ResponseEncodable where Value: ResponseEncodable {
    /// See `HTTPResponseEncodable`.
    public func encodeResponse(for req: HTTPRequest, using ctx: Context) -> EventLoopFuture<HTTPResponse> {
        return self.flatMap { t in
            return t.encodeResponse(for: req, using: ctx)
        }
    }
}

private let staticStringHeaders: HTTPHeaders = ["content-type": "text/plain; charset=utf-8"]
