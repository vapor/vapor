#if compiler(>=5.5)
import _NIOConcurrency

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension RoutesBuilder {
    @discardableResult
    public func get<Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: ResponseEncodable
    {
        return self.on(.GET, path, use: closure)
    }

    @discardableResult
    public func get<Response>(
        _ path: [PathComponent],
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: ResponseEncodable
    {
        return self.on(.GET, path, use: closure)
    }

    @discardableResult
    public func post<Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: ResponseEncodable
    {
        return self.on(.POST, path, use: closure)
    }

    @discardableResult
    public func post<Response>(
        _ path: [PathComponent],
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: ResponseEncodable
    {
        return self.on(.POST, path, use: closure)
    }

    @discardableResult
    public func patch<Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: ResponseEncodable
    {
        return self.on(.PATCH, path, use: closure)
    }

    @discardableResult
    public func patch<Response>(
        _ path: [PathComponent],
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: ResponseEncodable
    {
        return self.on(.PATCH, path, use: closure)
    }

    @discardableResult
    public func put<Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: ResponseEncodable
    {
        return self.on(.PUT, path, use: closure)
    }

    @discardableResult
    public func put<Response>(
        _ path: [PathComponent],
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: ResponseEncodable
    {
        return self.on(.PUT, path, use: closure)
    }

    @discardableResult
    public func delete<Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: ResponseEncodable
    {
        return self.on(.DELETE, path, use: closure)
    }

    @discardableResult
    public func delete<Response>(
        _ path: [PathComponent],
        use closure: @escaping (Request) async throws -> Response
    ) -> Route
        where Response: ResponseEncodable
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
        where Response: ResponseEncodable
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
        where Response: ResponseEncodable
    {
        let responder = BasicResponder { request in
            if case .collect(let max) = body, request.body.data == nil {
                return request.body.collect(
                    max: max?.value ?? request.application.routes.defaultMaxBodySize.value
                ).flatMap { _ -> EventLoopFuture<Response> in
                    let promise = request.eventLoop.makePromise(of: Response.self)
                    promise.completeWithAsync {
                        try await closure(request)
                    }
                    return promise.futureResult
                }.encodeResponse(for: request)
            } else {
                let promise = request.eventLoop.makePromise(of: Response.self)
                promise.completeWithAsync {
                    try await closure(request)
                }
                return promise.futureResult.encodeResponse(for: request)
            }
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
