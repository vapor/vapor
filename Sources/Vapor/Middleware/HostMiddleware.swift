/// A specification that can write a hostname to a Response
public struct HostnameWriter {
    /// A closure that can write a Response's Host header based on the `Request`
    internal typealias Modify = (Request, Response) -> ()
    
    /// See `Modify`
    internal var modify: Modify
    
    /// Sets the `Response`'s hostname to the `Requests` URI.hostname
    public static func adaptive() -> HostnameWriter {
        return self.init { request, response in
            response.http.headers[.host] = request.http.uri.hostname
        }
    }
    
    /// Always sets the hostname to the provided name
    public static func `static`(_ name: String) -> HostnameWriter {
        return self.init { _, response in
            response.http.headers[.host] = name
        }
    }
}

/// A middleware that changes the `Host` header field to either a preset hostname or a dynamic one
public final class HostMiddleware: Middleware {
    /// See `HostnameWriter`
    let hostnameWriter: HostnameWriter
    
    /// Creates a new Hostname writing middleware based on a `HostnameWriter` specification
    public init(writer: HostnameWriter) {
        self.hostnameWriter = writer
    }
    
    /// Updates the returned response to write the hostname
    public func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        // Since `Response` is a class we don't need to transform  it
        // We can change the variables by reference instead
        return try next.respond(to: request).do { response in
            self.hostnameWriter.modify(request, response)
        }
    }
}
