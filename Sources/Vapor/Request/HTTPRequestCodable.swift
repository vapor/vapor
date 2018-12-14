import NIO
import HTTP

#warning("TODO: consider whether this needs to be async")

/// Can be initialized from a `Request`.
public protocol HTTPRequestDecodable {
    /// Decodes an instance of `Self` asynchronously from a `Request`.
    ///
    /// - parameters:
    ///     - req: The `HTTPRequest` to initialize from.
    /// - returns: A `Future` containing an instance of `Self`.
    static func decode(from req: HTTPRequest, on eventLoop: EventLoop) -> EventLoopFuture<Self>
}

/// Can convert `self` to a `Request`.
public protocol HTTPRequestEncodable {
    /// Encodes an instance of `Self` asynchronously to a `Request`.
    ///
    /// - parameters:
    ///     - container: `Container` to use for initializing the `Request`.
    /// - returns: A `Future` containing the `Request`.
    func encode(on eventLoop: EventLoop) -> EventLoopFuture<HTTPRequest>
}

/// Can be converted to and from a `Request`.
public typealias HTTPRequestCodable = HTTPRequestDecodable & HTTPRequestEncodable

// MARK: Default Conformances

extension HTTPRequest: HTTPRequestCodable {
    /// See `HTTPRequestDecodable`.
    public static func decode(from req: HTTPRequest, on eventLoop: EventLoop) -> EventLoopFuture<HTTPRequest> {
        return eventLoop.makeSucceededFuture(result: req)
    }

    /// See `HTTPRequestEncodable`.
    public func encode(on eventLoop: EventLoop) -> EventLoopFuture<HTTPRequest> {
        return eventLoop.makeSucceededFuture(result: self)
    }
}
