/// Can be initialized from a `Request`.
public protocol RequestDecodable {
    /// Decodes an instance of `Self` asynchronously from a `Request`.
    ///
    /// - parameters:
    ///     - req: The `Request` to initialize from.
    /// - returns: A `Future` containing an instance of `Self`.
    static func decode(from req: Request) throws -> Future<Self>
}

/// Can convert `self` to a `Request`.
public protocol RequestEncodable {
    /// Encodes an instance of `Self` asynchronously to a `Request`.
    ///
    /// - parameters:
    ///     - container: `Container` to use for initializing the `Request`.
    /// - returns: A `Future` containing the `Request`.
    func encode(using container: Container) throws -> Future<Request>
}

/// Can be converted to and from a `Request`.
public typealias RequestCodable = RequestDecodable & RequestEncodable

// MARK: Default Conformances

extension HTTPRequest: RequestCodable {
    /// See `RequestDecodable`.
    public static func decode(from req: Request) throws -> EventLoopFuture<HTTPRequest> {
        return req.eventLoop.newSucceededFuture(result: req.http)
    }

    /// See `RequestEncodable`.
    public func encode(using container: Container) throws -> Future<Request> {
        return container.eventLoop.newSucceededFuture(
            result: .init(http: self, using: container)
        )
    }
}
