import NIOCore
import NIOHTTP1
import RoutingKit

extension RoutesBuilder {
    @discardableResult
    @preconcurrency
    public func get<Response>(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: AsyncResponseEncodable
    {
        return self.on(.GET, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func get<Response>(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: AsyncResponseEncodable
    {
        return self.on(.GET, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func get(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Void
    ) -> Route {
        return self.on(.GET, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func get(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Void
    ) -> Route {
        return self.on(.GET, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func post<Response>(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: AsyncResponseEncodable
    {
        return self.on(.POST, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func post<Response>(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: AsyncResponseEncodable
    {
        return self.on(.POST, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func post(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Void
    ) -> Route {
        return self.on(.POST, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func post(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Void
    ) -> Route {
        return self.on(.POST, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func patch<Response>(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: AsyncResponseEncodable
    {
        return self.on(.PATCH, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func patch<Response>(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: AsyncResponseEncodable
    {
        return self.on(.PATCH, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func patch(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Void
    ) -> Route {
        return self.on(.PATCH, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func patch(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Void
    ) -> Route {
        return self.on(.PATCH, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func put<Response>(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: AsyncResponseEncodable
    {
        return self.on(.PUT, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func put<Response>(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: AsyncResponseEncodable
    {
        return self.on(.PUT, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func put(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Void
    ) -> Route {
        return self.on(.PUT, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func put(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Void
    ) -> Route {
        return self.on(.PUT, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func delete<Response>(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: AsyncResponseEncodable
    {
        return self.on(.DELETE, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func delete<Response>(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: AsyncResponseEncodable
    {
        return self.on(.DELETE, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func delete(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Void
    ) -> Route {
        return self.on(.DELETE, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func delete(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Void
    ) -> Route {
        return self.on(.DELETE, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func on<Response>(
        _ method: HTTPMethod,
        _ path: PathComponent...,
        body: HTTPBodyStreamStrategy = .collect,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: AsyncResponseEncodable
    {
        return self.on(method, path, body: body, use: { request in
            return try await closure(request)
        })
    }
    
    @discardableResult
    @preconcurrency
    public func on<Response>(
        _ method: HTTPMethod,
        _ path: [PathComponent],
        body: HTTPBodyStreamStrategy = .collect,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: AsyncResponseEncodable
    {
        let responder = AsyncBasicResponder { request in
            if case .collect(let max) = body, request.body.data == nil {
                _ = try await request.eventLoop.flatSubmit {
                    request.body.collect(max: max?.value ?? request.application.routes.defaultMaxBodySize.value)
                }.get()
                
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
    
    @discardableResult
    @preconcurrency
    public func on(
        _ method: HTTPMethod,
        _ path: PathComponent...,
        body: HTTPBodyStreamStrategy = .collect,
        use closure: @Sendable @escaping (Request) async throws -> Void
    ) -> Route {
        on(method, path, body: body, use: { (req: Request) -> HTTPStatus in
            try await closure(req)
            return .noContent
        })
    }
    
    @discardableResult
    @preconcurrency
    public func on(
        _ method: HTTPMethod,
        _ path: [PathComponent],
        body: HTTPBodyStreamStrategy = .collect,
        use closure: @Sendable @escaping (Request) async throws -> Void
    ) -> Route {
        on(method, path, body: body, use: { (req: Request) -> HTTPStatus in
            try await closure(req)
            return .noContent
        })
    }
}
