public enum HTTPBodyStreamStrategy {
    public static var collect: HTTPBodyStreamStrategy {
        return .collect(maxSize: 2 << 14)
    }
    case stream
    case collect(maxSize: Int)
}

extension RoutesBuilder {
    @discardableResult
    public func get<Request, Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request, Context) throws -> Response
    ) -> Route
        where Request: RequestDecodable, Response: ResponseEncodable
    {
        return self.on(.GET, path, use: closure)
    }
    
    @discardableResult
    public func post<Request, Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request, Context) throws -> Response
    ) -> Route
        where Request: RequestDecodable, Response: ResponseEncodable
    {
        return self.on(.POST, path, use: closure)
    }
    
    @discardableResult
    public func patch<Request, Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request, Context) throws -> Response
    ) -> Route
        where Request: RequestDecodable, Response: ResponseEncodable
    {
        return self.on(.PATCH, path, use: closure)
    }
    
    @discardableResult
    public func put<Request, Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request, Context) throws -> Response
    ) -> Route
        where Request: RequestDecodable, Response: ResponseEncodable
    {
        return self.on(.PUT, path, use: closure)
    }
    
    @discardableResult
    public func on<Response>(
        _ method: HTTPMethod,
        _ path: PathComponent...,
        body: HTTPBodyStreamStrategy = .collect,
        use closure: @escaping (HTTPRequest) throws -> Response
    ) -> Route
        where Response: ResponseEncodable
    {
        return self.on(method, path, body: body, use: { request, context in
            return try closure(request)
        })
    }
    
    @discardableResult
    public func on<Response>(
        _ method: HTTPMethod,
        _ path: PathComponent...,
        body: HTTPBodyStreamStrategy = .collect,
        use closure: @escaping (HTTPRequest, Context) throws -> Response
    ) -> Route
        where Response: ResponseEncodable
    {
        return self.on(method, path, body: body, use: closure)
    }
    
    @discardableResult
    public func on<Request, Response>(
        _ method: HTTPMethod,
        _ path: PathComponent...,
        body: HTTPBodyStreamStrategy = .collect,
        use closure: @escaping (Request, Context) throws -> Response
    ) -> Route
        where Request: RequestDecodable, Response: ResponseEncodable
    {
        return self.on(method, path, body: body, use: closure)
    }
    
    @discardableResult
    public func on<Request, Response>(
        _ method: HTTPMethod,
        _ path: [PathComponent],
        body: HTTPBodyStreamStrategy = .collect,
        use closure: @escaping (Request, Context) throws -> Response
    ) -> Route
        where Request: RequestDecodable, Response: ResponseEncodable
    {
        let responder = BasicResponder(eventLoop: self.eventLoop) { req, ctx in
            if case .collect(let max) = body, let stream = req.body.stream {
                var req = req
                return stream.consume(max: max).flatMap { body in
                    req.body = HTTPBody(buffer: body)
                    return Request.decodeRequest(req, using: ctx).flatMapThrowing { req -> Response in
                        return try closure(req, ctx)
                    }.encodeResponse(for: req, using: ctx)
                }
            } else {
                return Request.decodeRequest(req, using: ctx).flatMapThrowing { req -> Response in
                    return try closure(req, ctx)
                }.encodeResponse(for: req, using: ctx)
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
