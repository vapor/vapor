/// Responds to HTTP requests.
public protocol Client: Responder { }

// MARK: Convenience

extension Client {
    /// Sends an HTTP request from the client using the method, url, and containter.
    public func send(_ method: HTTPMethod, to url: String, using container: Container) -> Future<Response> {
        return then {
            let req = Request(using: container)
            req.http.method = method
            req.http.uri = URIParser().parse(data: url.data(using: .utf8)!)
            return try self.respond(to: req)
        }
    }

    /// Sends an HTTP request from the client using the method, url, content, and containter.
    public func send<C>(_ method: HTTPMethod, to url: String, content: C, using container: Container) -> Future<Response>
        where C: Content
    {
        return then {
            let req = Request(using: container)
            try req.content.encode(content)
            req.http.method = method
            req.http.uri = URIParser().parse(data: url.data(using: .utf8)!)
            return try self.respond(to: req)
        }
    }
}

// MARK: Container

extension Request {
    /// Creates a client then sends an HTTP request from
    /// the client using the method, url, and containter.
    public func send(_ method: HTTPMethod, to url: String) -> Future<Response> {
        return then {
            let client = try self.make(Client.self, for: Request.self)
            return client.send(method, to: url, using: self.eventLoop)
        }
    }

    /// Creates a client then sends an HTTP request from
    /// the client using the method, url, content, and containter.
    public func send<C>(_ method: HTTPMethod, to url: String, content: C) -> Future<Response>
        where C: Content
    {
        return then {
            let client = try self.make(Client.self, for: Request.self)
            return client.send(method, to: url, content: content, using: self.eventLoop)
        }
    }

    /// Creates a client and returns a response for the supplied request.
    public func send(_ request: Request) -> Future<Response> {
        return then {
            let client = try self.make(Client.self, for: Request.self)
            return try client.respond(to: request)
        }
    }
}
