import HTTP

extension Responder {
    /// Calls `.request(.get, ...)`
    public func get(
        _ uri: String,
        query: [String: NodeRepresentable] = [:],
        _ headers: [HeaderKey: String] = [:],
        _ body: BodyRepresentable? = nil,
        through middleware: [Middleware] = []
    ) throws  -> Response {
        return try request(.get, uri, query: query, headers, body, through: middleware)
    }
    
    /// Calls `.request(.post, ...)`
    public func post(
        _ uri: String,
        query: [String: NodeRepresentable] = [:],
        _ headers: [HeaderKey: String] = [:],
        _ body: BodyRepresentable? = nil,
        through middleware: [Middleware] = []
    ) throws  -> Response {
        return try request(.post, uri, query: query, headers, body, through: middleware)
    }
    
    /// Calls `.request(.patch, ...)`
    public func patch(
        _ uri: String,
        query: [String: NodeRepresentable] = [:],
        _ headers: [HeaderKey: String] = [:],
        _ body: BodyRepresentable? = nil,
        through middleware: [Middleware] = []
    ) throws  -> Response {
        return try request(.patch, uri, query: query, headers, body, through: middleware)
    }
    
    /// Calls `.request(.put, ...)`
    public func put(
        _ uri: String,
        query: [String: NodeRepresentable] = [:],
        _ headers: [HeaderKey: String] = [:],
        _ body: BodyRepresentable? = nil,
        through middleware: [Middleware] = []
    ) throws  -> Response {
        return try request(.put, uri, query: query, headers, body, through: middleware)
    }
    
    
    /// Calls `.request(.delete, ...)`
    public func delete(
        _ uri: String,
        query: [String: NodeRepresentable] = [:],
        _ headers: [HeaderKey: String] = [:],
        _ body: BodyRepresentable? = nil,
        through middleware: [Middleware] = []
    ) throws  -> Response {
        return try request(.delete, uri, query: query, headers, body, through: middleware)
    }
}
