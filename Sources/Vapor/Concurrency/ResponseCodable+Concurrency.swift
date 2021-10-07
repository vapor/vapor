#if compiler(>=5.5) && canImport(_Concurrency)
import NIOCore

/// Can convert `self` to a `Response`.
///
/// Types that conform to this protocol can be returned in route closures.
///
/// This is the async version of `ResponseEncodable`
@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
public protocol AsyncResponseEncodable {
    /// Encodes an instance of `Self` to a `HTTPResponse`.
    ///
    /// - parameters:
    ///     - for: The `HTTPRequest` associated with this `HTTPResponse`.
    /// - returns: An `HTTPResponse`.
    func encodeResponse(for request: Request) async throws -> Response
}

/// Can convert `Request` to a `Self`.
///
/// Types that conform to this protocol can decode requests to their type.
///
/// This is the async version of `RequestDecodable`
@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
public protocol AsyncRequestDecodable {
    /// Decodes an instance of `HTTPRequest` to a `Self`.
    ///
    /// - parameters:
    ///     - request: The `HTTPRequest` to be decoded.
    /// - returns: An asynchronous `Self`.
    static func decodeRequest(_ request: Request) async throws -> Self
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension Request: AsyncRequestDecodable {
    public static func decodeRequest(_ request: Request) async throws -> Request {
        return request
    }
}

// MARK: Convenience

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension AsyncResponseEncodable {
    /// Asynchronously encodes `Self` into a `Response`, setting the supplied status and headers.
    ///
    ///     router.post("users") { req async throws -> HTTPResponse in
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
    public func encodeResponse(status: HTTPStatus, headers: HTTPHeaders = [:], for request: Request) -> EventLoopFuture<Response> {
        let response = try await self.encodeResponse(for: request)
        for (name, value) in headers {
            response.headers.replaceOrAdd(name: name, value: value)
        }
        response.status = status
        return response
    }
}

// MARK: Default Conformances

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension Response: AsyncResponseEncodable {
    /// See `AsyncResponseCodable`.
    public func encodeResponse(for request: Request) async throws -> Response {
        return self
    }
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension StaticString: AsyncResponseEncodable {
    /// See `AsyncResponseEncodable`.
    public func encodeResponse(for request: Request) async throws -> Response {
        let res = Response(headers: staticStringHeaders, body: .init(staticString: self))
        return res
    }
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension String: AsyncResponseEncodable {
    /// See `AsyncResponseEncodable`.
    public func encodeResponse(for request: Request) async throws -> Response {
        let res = Response(headers: staticStringHeaders, body: .init(string: self))
        return res
    }
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension Content: AsyncRequestDecodable, AsyncResponseEncodable {
    public func encodeResponse(for request: Request) async throws -> Response {
        let response = Response()
        try response.content.encode(self)
        return response
    }
    
    public static func decodeRequest(_ request: Request) async throws -> Self {
        let content = try request.content.decode(Self.self)
        return content
    }
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension Array: AsyncResponseEncodable, AsyncRequestDecodable where Element: Content {
    public static var defaultContentType: HTTPMediaType {
        return .json
    }
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension Dictionary: AsyncResponseEncodable, AsyncRequestDecodable where Key == String, Value: Content {
    public static var defaultContentType: HTTPMediaType {
        return .json
    }
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension ClientResponse: AsyncResponseEncodable {
    public func encodeResponse(for request: Request) async throws -> Response {
        let body: Response.Body
        if let buffer = self.body {
            body = .init(buffer: buffer)
        } else {
            body = .empty
        }
        let response = Response(
            status: self.status,
            headers: self.headers,
            body: body
        )
        return response
    }
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension View: AsyncResponseEncodable {
    public func encodeResponse(for request: Request) async throws -> Response {
        let response = Response()
        response.headers.contentType = .html
        response.body = .init(buffer: self.data)
        return response
    }
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension HTTPStatus: AsyncResponseEncodable {
    public func encodeResponse(for request: Request) async throws -> Response {
        return Response(status: self)
    }
}



#endif
