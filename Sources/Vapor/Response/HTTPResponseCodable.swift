import NIO
import NIOHTTP1
import HTTP

/// Can create an instance of `Self` from a `Response`.
public protocol HTTPResponseDecodable {
    /// Decodes an instance of `Self` asynchronously from a `Response`.
    ///
    /// - parameters:
    ///     - res: `Response` to decode.
    ///     - req: The `Request` associated with this `Response`.
    /// - returns: A `Future` containing the decoded instance of `Self`.
    static func decode(from res: HTTPResponse, for req: HTTPRequest) -> EventLoopFuture<Self>
}

/// Can convert `self` to a `Response`.
///
/// Types that conform to this protocol can be returned in route closures.
public protocol HTTPResponseEncodable {
    /// Encodes an instance of `Self` asynchronously to a `Response`.
    ///
    /// - parameters:
    ///     - req: The `Request` associated with this `Response`.
    /// - returns: A `Future` containing the `Response`.
    func encode(for req: HTTPRequest) -> EventLoopFuture<HTTPResponse>
}

/// Can be converted to and from a `Response`.
public typealias HTTPResponseCodable = HTTPResponseDecodable & HTTPResponseEncodable

// MARK: Convenience

extension HTTPResponseEncodable {
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
    public func encode(status: HTTPStatus, headers: HTTPHeaders = [:], for req: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        return self.encode(for: req).map { res in
            for (name, value) in headers {
                res.headers.replaceOrAdd(name: name, value: value)
            }
            res.status = status
            return res
        }
    }
}

// MARK: Default Conformances

extension HTTPResponse: HTTPResponseEncodable {
    /// See `ResponseEncodable`.
    public func encode(for req: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        #warning("TODO: add non-future return type to remove dep on request channel")
        return req.channel!.eventLoop.makeSucceededFuture(result: self)
    }
}

extension EventLoopFuture: HTTPResponseEncodable where T: HTTPResponseEncodable {
    /// See `ResponseEncodable`.
    public func encode(for req: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        return self.then { $0.encode(for: req) }
    }
}

extension StaticString: HTTPResponseEncodable {
    /// See `ResponseEncodable`.
    public func encode(for req: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        let res = HTTPResponse(headers: staticStringHeaders, body: self)
        return req.channel!.eventLoop.makeSucceededFuture(result: res)
    }
}

extension String: HTTPResponseEncodable {
    /// See `ResponseEncodable`.
    public func encode(for req: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        let res = HTTPResponse(headers: staticStringHeaders, body: self)
        return req.channel!.eventLoop.makeSucceededFuture(result: res)
    }
}

private let staticStringHeaders: HTTPHeaders = ["content-type": "text/plain; charset=utf-8"]
