import HTTP

extension ClientProtocol {
    /// Calls `.request(.get, ...)`
    public static func get(
        _ uri: String,
        query: [String: NodeRepresentable] = [:],
        _ headers: [HeaderKey: String] = [:],
        _ body: BodyRepresentable? = nil,
        through middleware: [Middleware] = []
    ) throws  -> Response {
        return try request(.get, uri, query: query, headers, body, through: middleware)
    }
    
    /// Calls `.request(.post, ...)`
    public static func post(
        _ uri: String,
        query: [String: NodeRepresentable] = [:],
        _ headers: [HeaderKey: String] = [:],
        _ body: BodyRepresentable? = nil,
        through middleware: [Middleware] = []
    ) throws  -> Response {
        return try request(.post, uri, query: query, headers, body, through: middleware)
    }
    
    /// Calls `.request(.patch, ...)`
    public static func patch(
        _ uri: String,
        query: [String: NodeRepresentable] = [:],
        _ headers: [HeaderKey: String] = [:],
        _ body: BodyRepresentable? = nil,
        through middleware: [Middleware] = []
    ) throws  -> Response {
        return try request(.patch, uri, query: query, headers, body, through: middleware)
    }
    
    /// Calls `.request(.put, ...)`
    public static func put(
        _ uri: String,
        query: [String: NodeRepresentable] = [:],
        _ headers: [HeaderKey: String] = [:],
        _ body: BodyRepresentable? = nil,
        through middleware: [Middleware] = []
    ) throws  -> Response {
        return try request(.put, uri, query: query, headers, body, through: middleware)
    }
    
    
    /// Calls `.request(.delete, ...)`
    public static func delete(
        _ uri: String,
        query: [String: NodeRepresentable] = [:],
        _ headers: [HeaderKey: String] = [:],
        _ body: BodyRepresentable? = nil,
        through middleware: [Middleware] = []
    ) throws  -> Response {
        return try request(.delete, uri, query: query, headers, body, through: middleware)
    }
}
