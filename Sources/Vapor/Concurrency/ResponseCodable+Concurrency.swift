import NIOCore

/// Can convert `self` to a `Response`.
///
/// Types that conform to this protocol can be returned in route closures.
///
/// This is the async version of `ResponseEncodable`
public protocol AsyncResponseEncodable {
    /// Encodes an instance of `Self` to a `HTTPResponse`.
    ///
    /// - parameters:
    ///     - for: The `HTTPRequest` associated with this `HTTPResponse`.
    /// - returns: An `HTTPResponse`.
    #if compiler(>=5.5) && canImport(_Concurrency)
    @available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
    func encodeResponse(for request: Request) async throws -> Response
    #endif
}

/// Can convert `Request` to a `Self`.
///
/// Types that conform to this protocol can decode requests to their type.
///
/// This is the async version of `RequestDecodable`
public protocol AsyncRequestDecodable {
    /// Decodes an instance of `HTTPRequest` to a `Self`.
    ///
    /// - parameters:
    ///     - request: The `HTTPRequest` to be decoded.
    /// - returns: An asynchronous `Self`.
    #if compiler(>=5.5) && canImport(_Concurrency)
    @available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
    static func decodeRequest(_ request: Request) async throws -> Self
    #endif
}

extension Request: AsyncRequestDecodable {
    #if compiler(>=5.5) && canImport(_Concurrency)
    @available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
    public static func decodeRequest(_ request: Request) async throws -> Request {
        return request
    }
    #endif
}

// MARK: Convenience
#if compiler(>=5.5) && canImport(_Concurrency)
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
    public func encodeResponse(status: HTTPStatus, headers: HTTPHeaders = [:], for request: Request) async throws -> Response {
        let response = try await self.encodeResponse(for: request)
        for (name, value) in headers {
            response.headers.replaceOrAdd(name: name, value: value)
        }
        response.status = status
        return response
    }
}
#endif

// MARK: Default Conformances

extension Response: AsyncResponseEncodable {
    // See `AsyncResponseCodable`.
    #if compiler(>=5.5) && canImport(_Concurrency)
    @available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
    public func encodeResponse(for request: Request) async throws -> Response {
        return self
    }
    #endif
}

extension StaticString: AsyncResponseEncodable {
    // See `AsyncResponseEncodable`.
    #if compiler(>=5.5) && canImport(_Concurrency)
    @available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
    public func encodeResponse(for request: Request) async throws -> Response {
        let res = Response(headers: staticStringHeaders, body: .init(staticString: self), byteBufferAllocator: request.byteBufferAllocator)
        return res
    }
    #endif
}

extension String: AsyncResponseEncodable {
    // See `AsyncResponseEncodable`.
    #if compiler(>=5.5) && canImport(_Concurrency)
    @available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
    public func encodeResponse(for request: Request) async throws -> Response {
        let res = Response(headers: staticStringHeaders, body: .init(string: self), byteBufferAllocator: request.byteBufferAllocator)
        return res
    }
    #endif
}

#if compiler(>=5.5) && canImport(_Concurrency)
@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension Content {
    public func encodeResponse(for request: Request) async throws -> Response {
        let response = Response(byteBufferAllocator: request.byteBufferAllocator)
        try response.content.encode(self)
        return response
    }

    public static func decodeRequest(_ request: Request) async throws -> Self {
        let content = try request.content.decode(Self.self)
        return content
    }
}
#endif

extension ClientResponse: AsyncResponseEncodable {
    #if compiler(>=5.5) && canImport(_Concurrency)
    @available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
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
            body: body,
            byteBufferAllocator: request.byteBufferAllocator
        )
        return response
    }
    #endif
}

extension HTTPStatus: AsyncResponseEncodable {
    #if compiler(>=5.5) && canImport(_Concurrency)
    @available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
    public func encodeResponse(for request: Request) async throws -> Response {
        return Response(status: self, byteBufferAllocator: request.byteBufferAllocator)
    }
    #endif
}
