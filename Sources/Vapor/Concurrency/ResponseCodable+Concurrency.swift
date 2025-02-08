import NIOCore
import NIOHTTP1

/// Can convert `self` to a `Response`.
///
/// Types that conform to this protocol can be returned in route closures.
///
/// This is the async version of `ResponseEncodable`
public protocol AsyncResponseEncodable {
    /// Encodes an instance of `Self` to a `Response`.
    ///
    /// - parameters:
    ///     - for: The `Request` associated with this `Response`.
    /// - returns: An `Response`.
    func encodeResponse(for request: Request) async throws -> Response
}

// MARK: Convenience
extension AsyncResponseEncodable {
    /// Asynchronously encodes `Self` into a `Response`, setting the supplied status and headers.
    ///
    ///     router.post("users") { req async throws -> Response in
    ///         return try await req.content
    ///             .decode(User.self)
    ///             .save(on: req)
    ///             .encode(status: .created, for: req)
    ///     }
    ///
    /// - parameters:
    ///     - status: `HTTPStatus` to set on the `Response`.
    ///     - headers: `HTTPHeaders` to merge into the `Response`'s headers.
    /// - returns: Newly encoded `Response`.
    public func encodeResponse(status: HTTPStatus, headers: HTTPHeaders = [:], for request: Request) async throws -> Response {
        let response = try await self.encodeResponse(for: request)
        response.responseBox.withLockedValue { box in
            for (name, value) in headers {
                box.headers.replaceOrAdd(name: name, value: value)
            }
            box.status = status
        }
        return response
    }
}

// MARK: Default Conformances

extension Response: AsyncResponseEncodable {
    // See `AsyncResponseCodable`.
    public func encodeResponse(for request: Request) async throws -> Response {
        return self
    }
}

extension StaticString: AsyncResponseEncodable {
    // See `AsyncResponseEncodable`.
    public func encodeResponse(for request: Request) async throws -> Response {
        let res = Response(headers: staticStringHeaders, body: .init(staticString: self))
        return res
    }
}

extension String: AsyncResponseEncodable {
    // See `AsyncResponseEncodable`.
    public func encodeResponse(for request: Request) async throws -> Response {
        let res = Response(headers: staticStringHeaders, body: .init(string: self))
        return res
    }
}

extension Content {
    public func encodeResponse(for request: Request) async throws -> Response {
        let response = Response()
        try response.content.encode(self)
        return response
    }
}
