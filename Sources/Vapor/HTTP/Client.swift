import Foundation

/// Responds to HTTP requests.
public protocol Client: Responder {
    /// The container to use for creating requests.
    var container: Container { get }
}

// MARK: Convenience

extension Client {
    /// Sends an HTTP request from the client using the method and url.
    public func send(
        _ method: HTTPMethod,
        headers: HTTPHeaders = .init(),
        to url: URLRepresentable
    ) -> Future<Response> {
        return Future.flatMap(on: container) {
            let req = Request(using: self.container)
            req.http.method = method
            req.http.url = url.converToURL()!
            req.http.headers = headers
            return try self.respond(to: req)
        }
    }

    /// Sends an HTTP request from the client using the method, url, and content.
    public func send<C>(
        _ method: HTTPMethod,
        headers: HTTPHeaders = .init(),
        to url: URLRepresentable,
        content: C
    ) -> Future<Response> where C: Content {
        return Future.flatMap(on: container) {
            let req = Request(using: self.container)
            req.http.method = method
            req.http.url = url.converToURL()!
            req.http.headers = headers
            try req.content.encode(content)
            return try self.respond(to: req)
        }
    }
}

/// MARK: Basic

extension Client {
    /// Sends a GET request without body
    public func get(_ url: URLRepresentable, headers: HTTPHeaders = .init()) -> Future<Response> {
        return send(.GET, headers: headers, to: url)
    }

    /// Sends a PUT request without body
    public func put(_ url: URLRepresentable, headers: HTTPHeaders = .init()) -> Future<Response> {
        return send(.PUT, headers: headers, to: url)
    }

    /// Sends a PUT request without body
    public func post(_ url: URLRepresentable, headers: HTTPHeaders = .init()) -> Future<Response> {
        return send(.POST, headers: headers, to: url)
    }

    /// Sends a POST request without body
    public func delete(_ url: URLRepresentable, headers: HTTPHeaders = .init()) -> Future<Response> {
        return send(.DELETE, headers: headers, to: url)
    }

    /// Sends a PATCH request without body
    public func patch(_ url: URLRepresentable, headers: HTTPHeaders = .init()) -> Future<Response> {
        return send(.PATCH, headers: headers, to: url)
    }
}

/// MARK: Content

extension Client {
    /// Sends a PUT request with body
    public func put<C>(_ url: URLRepresentable, headers: HTTPHeaders = .init(), content: C) -> Future<Response> where C: Content {
        return send(.PUT, headers: headers, to: url, content: content)
    }

    /// Sends a POST request with body
    public func post<C>(_ url: URLRepresentable, headers: HTTPHeaders = .init(), content: C) -> Future<Response> where C: Content {
        return send(.POST, headers: headers, to: url, content: content)
    }

    /// Sends a PATCH request with body
    public func patch<C>(_ url: URLRepresentable, headers: HTTPHeaders = .init(), content: C) -> Future<Response> where C: Content {
        return send(.PATCH, headers: headers, to: url, content: content)
    }
}

public protocol URLRepresentable {
    func converToURL() -> URL?
}

extension String: URLRepresentable {
    public func converToURL() -> URL? {
        return URL(string: self)
    }
}

extension URL: URLRepresentable {
    public func converToURL() -> URL? {
        return self
    }
}
