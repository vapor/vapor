import NIOCore
import NIOHTTP1
import RoutingKit

extension RoutesBuilder {
    @discardableResult
    @preconcurrency
    public func get<Response>(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> SendableRoute
    where Response: AsyncResponseEncodable
    {
        return self.on(.GET, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func get<Response>(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> SendableRoute
    where Response: AsyncResponseEncodable
    {
        return self.on(.GET, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func post<Response>(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> SendableRoute
    where Response: AsyncResponseEncodable
    {
        return self.on(.POST, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func post<Response>(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> SendableRoute
    where Response: AsyncResponseEncodable
    {
        return self.on(.POST, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func patch<Response>(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> SendableRoute
    where Response: AsyncResponseEncodable
    {
        return self.on(.PATCH, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func patch<Response>(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> SendableRoute
    where Response: AsyncResponseEncodable
    {
        return self.on(.PATCH, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func put<Response>(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> SendableRoute
    where Response: AsyncResponseEncodable
    {
        return self.on(.PUT, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func put<Response>(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> SendableRoute
    where Response: AsyncResponseEncodable
    {
        return self.on(.PUT, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func delete<Response>(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> SendableRoute
    where Response: AsyncResponseEncodable
    {
        return self.on(.DELETE, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func delete<Response>(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> SendableRoute
    where Response: AsyncResponseEncodable
    {
        return self.on(.DELETE, path, use: closure)
    }
    
    @discardableResult
    @preconcurrency
    public func on<Response>(
        _ method: HTTPMethod,
        _ path: PathComponent...,
        body: HTTPBodyStreamStrategy = .collect,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) -> SendableRoute
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
    ) -> SendableRoute
    where Response: AsyncResponseEncodable
    {
        let responder = AsyncBasicResponder { request in
            if case .collect(let max) = body, request.body.data == nil {
                _ = try await request.body.collect(
                    max: max?.value ?? request.application.routes.defaultMaxBodySize.value
                ).get()
                
            }
            return try await closure(request).encodeResponse(for: request)
        }
        let route = SendableRoute(
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
    public func on<Response>(
        _ method: HTTPMethod,
        _ path: [PathComponent],
        body: HTTPBodyStreamStrategy = .collect,
        use closure: @Sendable @escaping (Request) throws -> Response
    ) -> SendableRoute
    where Response: AsyncResponseEncodable
    {
        let responder = AsyncBasicResponder { request in
            if case .collect(let max) = body, request.body.data == nil {
                _ = try await request.body.collect(
                    max: max?.value ?? request.application.routes.defaultMaxBodySize.value
                ).get()
                
            }
            return try await closure(request).encodeResponse(for: request)
        }
        let route = SendableRoute(
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

// Deprecated
extension RoutesBuilder {
    @discardableResult
    @preconcurrency
    @_disfavoredOverload
    @available(*, deprecated, message: "Use SendableRoute instead")
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
    @_disfavoredOverload
    @available(*, deprecated, message: "Use SendableRoute instead")
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
    @_disfavoredOverload
    @available(*, deprecated, message: "Use SendableRoute instead")
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
    @_disfavoredOverload
    @available(*, deprecated, message: "Use SendableRoute instead")
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
    @_disfavoredOverload
    @available(*, deprecated, message: "Use SendableRoute instead")
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
    @_disfavoredOverload
    @available(*, deprecated, message: "Use SendableRoute instead")
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
    @_disfavoredOverload
    @available(*, deprecated, message: "Use SendableRoute instead")
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
    @_disfavoredOverload
    @available(*, deprecated, message: "Use SendableRoute instead")
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
    @_disfavoredOverload
    @available(*, deprecated, message: "Use SendableRoute instead")
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
    @_disfavoredOverload
    @available(*, deprecated, message: "Use SendableRoute instead")
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
    @_disfavoredOverload
    @available(*, deprecated, message: "Use SendableRoute instead")
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
    @_disfavoredOverload
    @available(*, deprecated, message: "Use SendableRoute instead")
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
}
