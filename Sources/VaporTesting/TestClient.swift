@testable public import Vapor
import Foundation
#warning("Migrate to our own SocketAddress")
import NIOCore
import NIOConcurrencyHelpers
import AsyncHTTPClient

public protocol TestClient: Client {
    var baseURL: URI? { get }
}

/// We need a way to track the different response bodies from requests. If we don't drain them
/// then AHC will see a disconnect and hang up so we need to drain before return them.
/// This just helps us keep track and drain any that haven't been collected
final class UnreadBodies: Sendable {
    private let bodies = NIOLockedValueBox<[Response.Body]>([])

    func track(_ body: Response.Body) {
        self.bodies.withLockedValue { $0.append(body) }
    }

    func drain() async throws {
        let bodies = self.bodies.withLockedValue { bodies in
            defer { bodies.removeAll() }
            return bodies
        }
        for var body in bodies where body.isUnconsumedStream {
            _ = try await body.collect()
        }
    }
}

struct InMemoryTestClient: TestClient {
    let app: Application
    let responder: any Responder
    let unreadBodies = UnreadBodies()
    let baseURL: URI? = nil
    var contentConfiguration: ContentConfiguration {
        self.app.contentConfiguration
    }

    func send(_ clientRequest: ClientRequest) async throws -> ClientResponse {
        // A request-target on the wire always starts with `/`, and the live client gets that for
        // free from the HTTP client. Match it here so `client.get("users")` routes the same way in
        // both modes instead of reaching the responder as a relative path.
        var url = clientRequest.url
        if !url.path.hasPrefix("/") {
            url.path = "/" + url.path
        }

        let request = Request(
            method: clientRequest.method,
            url: url,
            headers: clientRequest.headers,
            collectedBody: clientRequest.body,
            remoteAddress: nil,
            contentConfiguration: self.app.contentConfiguration,
            defaultMaxBodySize: self.app.routes.defaultMaxBodySize
        )

        let response = try await self.responder.respond(to: request)
        self.unreadBodies.track(response.body)
        return ClientResponse(
            status: response.status,
            headers: response.headers,
            body: response.body,
            maxBodySize: clientRequest.maxResponseBodySize,
            contentConfiguration: self.app.contentConfiguration
        )
    }
}

struct LiveTestClient: TestClient {
    let app: Application
    let address: SocketAddress
    let options: LiveClientOptions
    let http: HTTPClient
    let unreadBodies = UnreadBodies()

    var port: Int { self.address.port! }
    var baseURL: URI? {
        URI(scheme: self.app.serverConfiguration.isTLSEnabled ? "https" : "http",
            host: self.address.ipAddress, port: self.port, path: "/")
    }
    var contentConfiguration: ContentConfiguration {
        self.app.contentConfiguration
    }

    func send(_ clientRequest: ClientRequest) async throws -> ClientResponse {
        var request = clientRequest
        request.url = self.resolve(clientRequest.url)
        request.timeout = self.options.timeout

        let response = try await VaporHTTPClient(http: self.http, contentConfiguration: self.contentConfiguration)
            .send(request)
        self.unreadBodies.track(response.body)
        return response
    }
}

extension TestClient {
    /// A bare path resolves against the app; a full URL is left alone so a test can
    /// deliberately point at somewhere else (a stub, a second app).
    ///
    /// In memory there is no base URL, so the path goes through untouched: the responder
    /// only routes on the path anyway.
    package func resolve(_ url: URI) -> URI {
        guard url.host == nil, let base = self.baseURL else { return url }
        // Update URL components so we can send a real request. The path is kept as parsed because it is already percent-encoded
        var resolved = url
        if !resolved.path.hasPrefix("/") {
            resolved.path = "/" + resolved.path
        }
        resolved.scheme = base.scheme
        resolved.host = base.host
        resolved.port = base.port
        return resolved
    }
}
