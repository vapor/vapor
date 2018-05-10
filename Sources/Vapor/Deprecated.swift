// nothing here yet...

/// See `NIOServerConfig`.
@available(*, deprecated, renamed: "NIOServerConfig")
public typealias EngineServerConfig = NIOServerConfig

/// See `NIOServerConfig`.
@available(*, deprecated, renamed: "NIOServer")
public typealias EngineServer = NIOServer


extension Client {
    /// Sends a PUT request with body
    @available(*, deprecated, message: "Use beforeSend closure instead.")
    public func put<C>(_ url: URLRepresentable, headers: HTTPHeaders = .init(), content: C) -> Future<Response> where C: Content {
        return send(.PUT, headers: headers, to: url) { try $0.content.encode(content) }
    }

    /// Sends a POST request with body
    @available(*, deprecated, message: "Use beforeSend closure instead.")
    public func post<C>(_ url: URLRepresentable, headers: HTTPHeaders = .init(), content: C) -> Future<Response> where C: Content {
        return send(.POST, headers: headers, to: url) { try $0.content.encode(content) }
    }

    /// Sends a PATCH request with body
    @available(*, deprecated, message: "Use beforeSend closure instead.")
    public func patch<C>(_ url: URLRepresentable, headers: HTTPHeaders = .init(), content: C) -> Future<Response> where C: Content {
        return send(.PATCH, headers: headers, to: url) { try $0.content.encode(content) }
    }
}

extension MemorySessions {
    /// See `MemorySessions`.
    @available(*, deprecated, renamed: "init()")
    public convenience init(on worker: Worker) {
        self.init()
    }
}

extension Request {
    /// See `req.response(http:)`.
    @available(*, deprecated, renamed: "response(http:)")
    public func makeResponse(http: HTTPResponse = .init()) -> Response {
        return response(http: http)
    }
    
    /// See `req.response(_ body:as:)`.
    @available(*, deprecated, renamed: "response(_body:as:)")
    public func makeResponse(_ body: LosslessHTTPBodyRepresentable, as contentType: MediaType = .plainText) -> Response {
        return response(body, as: contentType)
    }
}
