import NIOCore
import RoutingKit
import HTTPTypes

extension RoutesBuilder {
    @discardableResult
    @preconcurrency
    public func get<Response>(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: ResponseEncodable
    {
        return self.on(.get, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func get<Response>(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: ResponseEncodable
    {
        return self.on(.get, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func post<Response>(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: ResponseEncodable
    {
        return self.on(.post, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func post<Response>(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: ResponseEncodable
    {
        return self.on(.post, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func patch<Response>(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: ResponseEncodable
    {
        return self.on(.patch, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func patch<Response>(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: ResponseEncodable
    {
        return self.on(.patch, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func put<Response>(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: ResponseEncodable
    {
        return self.on(.put, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func put<Response>(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: ResponseEncodable
    {
        return self.on(.put, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func delete<Response>(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: ResponseEncodable
    {
        return self.on(.delete, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func delete<Response>(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: ResponseEncodable
    {
        return self.on(.delete, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func on<Response>(
        _ method: HTTPRequest.Method,
        _ path: PathComponent...,
        body: HTTPBodyStreamStrategy = .collect,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: ResponseEncodable
    {
        return self.on(method, path, body: body, use: { request in
            return try await closure(request)
        })
    }
    
    @discardableResult
    @preconcurrency
    public func on<Response>(
        _ method: HTTPRequest.Method,
        _ path: [PathComponent],
        body: HTTPBodyStreamStrategy = .collect,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> Route
    where Response: ResponseEncodable
    {
        let responder = BasicResponder { request in
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
}
