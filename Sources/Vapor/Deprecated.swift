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

extension Array where Element == Middleware {
    /// Wraps a `Responder` in an array of `Middleware` creating a new `Responder`.
    /// - note: The array of middleware must be `[Middleware]` not `[M] where M: Middleware`.
    @available(*, deprecated, message: "label 'chainedto' was renamed 'chainingTo'.")
    public func makeResponder(chainedto responder: Responder) -> Responder {
        return makeResponder(chainingTo: responder)
    }
}

