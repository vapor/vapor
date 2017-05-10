import HTTP
import URI

// MARK: Base

extension Responder {
    /// Creates a new client from the information in the
    /// Request URI and uses it to respond to the request.
    public func respond(
        to req: Request,
        through middleware: [Middleware] = []
    ) throws -> Response {
        return try middleware
            .chain(to: self)
            .respond(to: req)
    }
    
    /// Creates a new client and calls `.respond()`
    /// using the request method and uri provided.
    public func request(
        _ method: Method,
        _ uri: String,
        query: [String: NodeRepresentable] = [:],
        _ headers: [HeaderKey: String] = [:],
        _ body: BodyRepresentable? = nil,
        through middleware: [Middleware] = []
    ) throws  -> Response {
        let uri = try URI(uri)
    
        let req = Request(method: method, uri: uri)
        req.headers = headers
        
        for (key, value) in query {
            try req.query?.set(key, value)
        }
        
        if let body = body {
            req.body = body.makeBody()
        }
        return try respond(to: req, through: middleware)
    }
}

// MARK: Method specific

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
