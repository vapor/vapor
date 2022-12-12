#if compiler(>=5.5) && canImport(_Concurrency)
import NIOCore

@available(macOS 10.15, iOS 15, watchOS 8, tvOS 15, *)
extension RoutesBuilder {
    @discardableResult
    public func get<Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: AsyncResponseEncodable
    {
        return self.on(.GET, path, use: closure)
    }

    @discardableResult
    public func get<Response>(
        _ path: [PathComponent],
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: AsyncResponseEncodable
    {
        return self.on(.GET, path, use: closure)
    }

    @discardableResult
    public func post<Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: AsyncResponseEncodable
    {
        return self.on(.POST, path, use: closure)
    }

    @discardableResult
    public func post<Response>(
        _ path: [PathComponent],
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: AsyncResponseEncodable
    {
        return self.on(.POST, path, use: closure)
    }

    @discardableResult
    public func patch<Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: AsyncResponseEncodable
    {
        return self.on(.PATCH, path, use: closure)
    }

    @discardableResult
    public func patch<Response>(
        _ path: [PathComponent],
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: AsyncResponseEncodable
    {
        return self.on(.PATCH, path, use: closure)
    }

    @discardableResult
    public func put<Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: AsyncResponseEncodable
    {
        return self.on(.PUT, path, use: closure)
    }

    @discardableResult
    public func put<Response>(
        _ path: [PathComponent],
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: AsyncResponseEncodable
    {
        return self.on(.PUT, path, use: closure)
    }

    @discardableResult
    public func delete<Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: AsyncResponseEncodable
    {
        return self.on(.DELETE, path, use: closure)
    }

    @discardableResult
    public func delete<Response>(
        _ path: [PathComponent],
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: AsyncResponseEncodable
    {
        return self.on(.DELETE, path, use: closure)
    }

    @discardableResult
    public func on<Response>(
        _ method: HTTPMethod,
        _ path: PathComponent...,
        body: HTTPBodyStreamStrategy = .collect,
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: AsyncResponseEncodable
    {
        return self.on(method, path, body: body, use: { request in
            return try await closure(request)
        })
    }

    @discardableResult
    public func on<Response>(
        _ method: HTTPMethod,
        _ path: [PathComponent],
        body: HTTPBodyStreamStrategy = .collect,
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: AsyncResponseEncodable
    {
        let responder = AsyncBasicResponder { request in
            if case .collect(let max) = body, request.body.data == nil {
                _ = try await request.body.collect(max: max?.value ?? request.application.routes.defaultMaxBodySize.value).get()
                
            }
            return try await closure(request).encodeResponse(for: request)
        }
        let route = Route(
            method: method,
            path: path,
            responder: responder,
            requestType: Request.self,
            responseType: Response.self
        )
        self.add(route)
        return route
    }
}

#endif
