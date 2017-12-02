/// Responds to HTTP requests.
public protocol Client: Responder {
    /// The container to use for creating requests.
    var container: Container { get }
}

// MARK: Convenience

extension Client {
    /// Sends an HTTP request from the client using the method and url.
    public func send(_ method: HTTPMethod, to url: String) -> Future<Response> {
        return then {
            let req = Request(using: self.container)
            req.http.method = method
            req.http.uri = URIParser().parse(data: url.data(using: .utf8)!)
            return try self.respond(to: req)
        }
    }

    /// Sends an HTTP request from the client using the method, url, and content.
    public func send<C>(_ method: HTTPMethod, to url: String, content: C) -> Future<Response>
        where C: Content
    {
        return then {
            let req = Request(using: self.container)
            try req.content.encode(content)
            req.http.method = method
            req.http.uri = URIParser().parse(data: url.data(using: .utf8)!)
            return try self.respond(to: req)
        }
    }
}
