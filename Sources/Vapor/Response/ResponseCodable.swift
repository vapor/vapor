/// Can convert `self` to a `Response`.
///
/// Types that conform to this protocol can be returned in route closures.
public protocol ResponseEncodable {
    /// Encodes an instance of `Self` to a `HTTPResponse`.
    ///
    /// - parameters:
    ///     - for: The `HTTPRequest` associated with this `HTTPResponse`.
    /// - returns: An `HTTPResponse`.
    func encodeResponse(for request: Request) -> EventLoopFuture<Response>
}

public protocol RequestDecodable {
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
    /// See `HTTPResponseCodable`.
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        return request.eventLoop.makeSucceededFuture(self)
    }
}

extension StaticString: ResponseEncodable {
    /// See `HTTPResponseEncodable`.
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let res = Response(headers: staticStringHeaders, body: .init(staticString: self))
        return request.eventLoop.makeSucceededFuture(res)
    }
}

extension String: ResponseEncodable {
    /// See `HTTPResponseEncodable`.
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let res = Response(headers: staticStringHeaders, body: .init(string: self))
        return request.eventLoop.makeSucceededFuture(res)
    }
}

extension EventLoopFuture: ResponseEncodable where Value: ResponseEncodable {
    /// See `HTTPResponseEncodable`.
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        return self.flatMap { t in
            return t.encodeResponse(for: request)
        }
    }
}

private let staticStringHeaders: HTTPHeaders = ["content-type": "text/plain; charset=utf-8"]
