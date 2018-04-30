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

// MARK: Default Conformances

extension HTTPResponse: ResponseEncodable {
    /// See `ResponseEncodable`.
    public func encode(for req: Request) throws -> Future<Response> {
        let new = req.makeResponse()
        new.http = self
        return req.eventLoop.newSucceededFuture(result: new)
    }
}

extension StaticString: ResponseEncodable {
    /// See `ResponseEncodable`.
    public func encode(for req: Request) throws -> Future<Response> {
        let res = Response(http: .init(headers: staticStringHeaders, body: self), using: req.sharedContainer)
        return req.eventLoop.newSucceededFuture(result: res)
    }
}

private let staticStringHeaders: HTTPHeaders = ["Content-Type": "text/plain"]
