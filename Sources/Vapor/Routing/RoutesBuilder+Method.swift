public import RoutingKit
public import HTTPTypes

extension RoutesBuilder {
    @discardableResult
    public func get(
        _ path: PathComponent...,
        routeDescription: String? = nil,
        use closure: @Sendable @escaping (Request) async throws -> some ResponseEncodable
    ) -> Route {
        self.on(.get, path, routeDescription: routeDescription, use: closure)
    }

    @discardableResult
    public func get(
        _ path: [PathComponent],
        routeDescription: String? = nil,
        use closure: @Sendable @escaping (Request) async throws -> some ResponseEncodable
    ) -> Route {
        self.on(.get, path, routeDescription: routeDescription, use: closure)
    }

    @discardableResult
    public func post(
        _ path: PathComponent...,
        routeDescription: String? = nil,
        use closure: @Sendable @escaping (Request) async throws -> some ResponseEncodable
    ) -> Route {
        self.on(.post, path, routeDescription: routeDescription, use: closure)
    }

    @discardableResult
    public func post(
        _ path: [PathComponent],
        routeDescription: String? = nil,
        use closure: @Sendable @escaping (Request) async throws -> some ResponseEncodable
    ) -> Route {
        self.on(.post, path, routeDescription: routeDescription, use: closure)
    }

    @discardableResult
    public func patch(
        _ path: PathComponent...,
        routeDescription: String? = nil,
        use closure: @Sendable @escaping (Request) async throws -> some ResponseEncodable
    ) -> Route {
        self.on(.patch, path, routeDescription: routeDescription, use: closure)
    }

    @discardableResult
    public func patch(
        _ path: [PathComponent],
        routeDescription: String? = nil,
        use closure: @Sendable @escaping (Request) async throws -> some ResponseEncodable
    ) -> Route {
        self.on(.patch, path, routeDescription: routeDescription, use: closure)
    }

    @discardableResult
    public func put(
        _ path: PathComponent...,
        routeDescription: String? = nil,
        use closure: @Sendable @escaping (Request) async throws -> some ResponseEncodable
    ) -> Route {
        self.on(.put, path, routeDescription: routeDescription, use: closure)
    }

    @discardableResult
    public func put(
        _ path: [PathComponent],
        routeDescription: String? = nil,
        use closure: @Sendable @escaping (Request) async throws -> some ResponseEncodable
    ) -> Route {
        self.on(.put, path, routeDescription: routeDescription, use: closure)
    }

    @discardableResult
    public func delete(
        _ path: PathComponent...,
        routeDescription: String? = nil,
        use closure: @Sendable @escaping (Request) async throws -> some ResponseEncodable
    ) -> Route {
        self.on(.delete, path, routeDescription: routeDescription, use: closure)
    }

    @discardableResult
    public func delete(
        _ path: [PathComponent],
        routeDescription: String? = nil,
        use closure: @Sendable @escaping (Request) async throws -> some ResponseEncodable
    ) -> Route {
        self.on(.delete, path, routeDescription: routeDescription, use: closure)
    }

    @discardableResult
    public func query(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> some ResponseEncodable
    ) -> Route {
        self.on(.query, path, use: closure)
    }

    @discardableResult
    public func query(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> some ResponseEncodable
    ) -> Route {
        self.on(.query, path, use: closure)
    }

    /// Adds the closure to the given path for all HTTP methods
    /// besides custom ones, so GET, POST, PUT, PATCH, DELETE, QUERY, HEAD, OPTIONS.
    @discardableResult
    public func all(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> some ResponseEncodable
    ) -> [Route] {
        [HTTPRequest.Method.get, .post, .put, .patch, .delete, .query, .head, .options].map {
            self.on($0, path, use: closure)
        }
    }

    /// Adds the closure to the given path for all HTTP methods
    /// besides custom ones, so GET, POST, PUT, PATCH, DELETE, QUERY, HEAD, OPTIONS.
    @discardableResult
    public func all(
        _ path: [PathComponent],
        use closure: @Sendable @escaping (Request) async throws -> some ResponseEncodable
    ) -> [Route] {
        [HTTPRequest.Method.get, .post, .put, .patch, .delete, .query, .head, .options].map {
            self.on($0, path, use: closure)
        }
    }

    @discardableResult
    public func on(
        _ method: HTTPRequest.Method,
        _ path: PathComponent...,
        maxBodySize: ByteCount? = nil,
        routeDescription: String? = nil,
        use closure: @Sendable @escaping (Request) async throws -> some ResponseEncodable
    ) -> Route {
        self.on(method, path, maxBodySize: maxBodySize, routeDescription: routeDescription, use: { request in
            try await closure(request)
        })
    }

    @discardableResult
    public func on(
        _ method: HTTPRequest.Method,
        _ path: [PathComponent],
        maxBodySize: ByteCount? = nil,
        routeDescription: String? = nil,
        use closure: @Sendable @escaping (Request) async throws -> some ResponseEncodable
    ) -> Route {
        let responder = BasicResponder { request in
            // Bodies are lazy: nothing is buffered until the handler asks, by reading the body or by
            // decoding `content`. A route that names a `maxBodySize` is raising or lowering the
            // ceiling that collection will then enforce, not asking for the body up front.
            var request = request
            if let maxBodySize {
                request.maxBodySize = maxBodySize
            }
            return try await closure(request).encodeResponse(for: request)
        }
        let route = Route(
            method: method,
            path: path,
            responder: responder,
            requestType: Request.self,
            responseType: Response.self,
            routeDescription: routeDescription
        )
        self.add(route)
        return route
    }
}
