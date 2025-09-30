import HTTPTypes

/// Can convert `self` to a `Response`.
///
/// Types that conform to this protocol can be returned in route closures.
public protocol ResponseEncodable: SendableMetatype {
    /// Encodes an instance of `Self` to a `Response`.
    ///
    /// - parameters:
    ///     - for: The `Request` associated with this `Response`.
    /// - returns: A `Response`.
    func encodeResponse(for request: Request) async throws -> Response
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
    static func decodeRequest(_ request: Request) async throws -> Self
}

extension Request: RequestDecodable {
    public static func decodeRequest(_ request: Request) async throws -> Request {
        request
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
    ///     - headers: `HTTPFields` to merge into the `Response`'s headers.
    /// - returns: Newly encoded `Response`.
    public func encodeResponse(status: HTTPStatus, headers: HTTPFields = [:], for request: Request) async throws -> Response {
        let response = try await encodeResponse(for: request)
        response.responseBox.withLockedValue { box in
            for header in headers {
                box.headers.append(header)
            }
            box.status = status
        }
        return response
    }
}

// MARK: Default Conformances

extension Response: ResponseEncodable {
    // See `ResponseEncodable`.
    public func encodeResponse(for request: Request) async throws -> Response {
        return self
    }
}

extension StaticString: ResponseEncodable {
    // See `AsyncResponseEncodable`.
    public func encodeResponse(for request: Request) async throws -> Response {
        let res = Response(headers: staticStringHeaders, body: .init(staticString: self), contentConfiguration: request.application.contentConfiguration)
        return res
    }
}

extension String: ResponseEncodable {
    // See `AsyncResponseEncodable`.
    public func encodeResponse(for request: Request) async throws -> Response {
        let res = Response(headers: staticStringHeaders, body: .init(string: self), contentConfiguration: request.application.contentConfiguration)
        return res
    }
}

internal let staticStringHeaders: HTTPFields = [.contentType: "text/plain; charset=utf-8"]
