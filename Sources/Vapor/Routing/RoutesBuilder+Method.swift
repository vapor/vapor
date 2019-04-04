public enum HTTPBodyStreamStrategy {
    public static var collect: HTTPBodyStreamStrategy {
        return .collect(maxSize: 2 << 14)
    }
    case stream
    case collect(maxSize: Int)
}

extension RoutesBuilder {
    @discardableResult
    public func get<Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request) throws -> Response
    ) -> Route
        where Response: ResponseEncodable
    {
        return self.on(.GET, path, use: closure)
    }
    
    @discardableResult
    public func post<Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request) throws -> Response
    ) -> Route
        where Response: ResponseEncodable
    {
        return self.on(.POST, path, use: closure)
    }
    
    @discardableResult
    public func patch<Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request) throws -> Response
    ) -> Route
        where Response: ResponseEncodable
    {
        return self.on(.PATCH, path, use: closure)
    }
    
    @discardableResult
    public func put<Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request) throws -> Response
    ) -> Route
        where Response: ResponseEncodable
    {
        return self.on(.PUT, path, use: closure)
    }
    
    @discardableResult
    public func on<Response>(
        _ method: HTTPMethod,
        _ path: PathComponent...,
        body: HTTPBodyStreamStrategy = .collect,
        use closure: @escaping (Request) throws -> Response
    ) -> Route
        where Response: ResponseEncodable
    {
        return self.on(method, path, body: body, use: { request in
            return try closure(request)
        })
    }
    
    @discardableResult
    public func on<Response>(
        _ method: HTTPMethod,
        _ path: [PathComponent],
        body: HTTPBodyStreamStrategy = .collect,
        use closure: @escaping (Request) throws -> Response
    ) -> Route
        where Response: ResponseEncodable
    {
        let responder = BasicResponder(eventLoop: self.eventLoop) { request in
            if case .collect(let max) = body, let stream = request.http.body.stream {
                return stream.consume(max: max).flatMapThrowing { body -> Response in
                    request.http.body = HTTPBody(buffer: body)
                    return try closure(request)
                }.encodeResponse(for: request)
            } else {
                return try closure(request)
                    .encodeResponse(for: request)
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
