/// Can create an instance of `Self` from a `Response`.
public protocol ResponseDecodable {
    /// Decodes an instance of `Self` asynchronously from a `Response`.
    ///
    /// - parameters:
    ///     - res: `Response` to decode.
    ///     - req: The `Request` associated with this `Response`.
    /// - returns: A `Future` containing the decoded instance of `Self`.
    static func decode(from res: Response, for req: Request) throws -> Future<Self>
}

/// Can convert `self` to a `Response`.
///
/// Types that conform to this protocol can be returned in route closures.
public protocol ResponseEncodable {
    /// Encodes an instance of `Self` asynchronously to a `Response`.
    ///
    /// - parameters:
    ///     - req: The `Request` associated with this `Response`.
    /// - returns: A `Future` containing the `Response`.
    func encode(for req: Request) throws -> Future<Response>
}

/// Can be converted to and from a `Response`.
public typealias ResponseCodable = ResponseDecodable & ResponseEncodable

// MARK: Convenience

extension ResponseEncodable {
    /// Asynchronously encodes `Self` into a `Response`, setting the supplied status and headers.
    ///
    ///     router.post("users") { req -> Future<Response> in
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
    public func encode(status: HTTPStatus, headers: HTTPHeaders = [:], for req: Request) -> Future<Response> {
        do {
            return try encode(for: req).map { res in
                for (name, value) in headers {
                    res.http.headers.replaceOrAdd(name: name, value: value)
                }
                res.http.status = status
                return res
            }
        } catch {
            return req.eventLoop.newFailedFuture(error: error)
        }
    }
}

// MARK: Default Conformances

extension HTTPResponse: ResponseEncodable {
    /// See `ResponseEncodable`.
    public func encode(for req: Request) throws -> Future<Response> {
        let new = req.response()
        new.http = self
        return req.eventLoop.newSucceededFuture(result: new)
    }
}

extension Future: ResponseEncodable where T: ResponseEncodable {
    /// See `ResponseEncodable`.
    public func encode(for req: Request) throws -> Future<Response> {
        return flatMap { try $0.encode(for: req) }
    }
}

extension StaticString: ResponseEncodable {
    /// See `ResponseEncodable`.
    public func encode(for req: Request) throws -> Future<Response> {
        let res = Response(http: .init(headers: staticStringHeaders, body: self), using: req.sharedContainer)
        return req.sharedContainer.eventLoop.newSucceededFuture(result: res)
    }
}

extension String: ResponseEncodable {
    /// See `ResponseEncodable`.
    public func encode(for req: Request) throws -> Future<Response> {
        let res = Response(http: .init(headers: staticStringHeaders, body: self), using: req.sharedContainer)
        return req.sharedContainer.eventLoop.newSucceededFuture(result: res)
    }
}

private let staticStringHeaders: HTTPHeaders = ["content-type": "text/plain; charset=utf-8"]
