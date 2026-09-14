@testable public import Vapor
import Foundation
import Synchronization
import AsyncHTTPClient
import Logging
import NIOPosix

public protocol TestClient: Client {
    var baseURL: URI? { get }

    /// Runs `body` with another client for the same application, set up with `options`.
    ///
    /// For a test that needs more than one kind of client against one running server - one that
    /// trusts the server's certificate and one that doesn't, say. The new client gets its own
    /// connections, so it never reuses one this client opened. In memory there are no connections
    /// to configure, and `body` is handed this client.
    func withOptions<T>(_ options: LiveClientOptions, _ body: (any TestClient) async throws -> T) async throws -> T
}

extension TestClient {
    /// The port the running server is bound to, or `nil` in memory.
    public var port: Int? {
        self.baseURL?.port
    }
}

/// We need a way to track the different response bodies from requests. If we don't drain them
/// then AHC will see a disconnect and hang up so we need to drain before return them.
/// This just helps us keep track and drain any that haven't been collected
final class UnreadBodies: Sendable {
    private let bodies = Mutex<[Response.Body]>([])

    func track(_ body: Response.Body) {
        self.bodies.withLock { $0.append(body) }
    }

    /// Reads the bodies a test left unread, so the routes producing them run to completion and the
    /// connections they arrived on are left reusable.
    ///
    /// Best effort: a body whose connection is already gone cannot be drained, and there is nothing
    /// left to tidy on it either. That happens legitimately - a route answers 413 with
    /// `Connection: close` while the test is still uploading, and the server resets the connection
    /// under the unread response. Throwing that out of the testing scope would fail a test whose own
    /// assertions have already passed, so a failed drain is dropped.
    func drain() async {
        let bodies = self.bodies.withLock { bodies in
            defer { bodies.removeAll() }
            return bodies
        }
        for var body in bodies where body.isUnconsumedStream {
            _ = try? await body.collect()
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

        var clientBody = clientRequest.body
        let collectedBody = try await clientBody.collect()

        let request = Request(
            method: clientRequest.method,
            url: url,
            headers: clientRequest.headers,
            collectedBody: collectedBody,
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

    func withOptions<T>(_ options: LiveClientOptions, _ body: (any TestClient) async throws -> T) async throws -> T {
        try await body(self)
    }
}

struct LiveTestClient: TestClient {
    let app: Application
    let address: SocketAddress
    let options: LiveClientOptions
    let http: HTTPClient
    /// Whether `http` decodes gzip and deflate bodies; see `AHCClient`.
    let decodesCompressedBodies: Bool
    let unreadBodies = UnreadBodies()

    var baseURL: URI? {
        URI(scheme: self.app.serverConfiguration.isTLSEnabled ? "https" : "http",
            host: self.address.host ?? "localhost", port: self.address.port, path: "/")
    }
    var contentConfiguration: ContentConfiguration {
        self.app.contentConfiguration
    }

    func send(_ clientRequest: ClientRequest) async throws -> ClientResponse {
        var request = clientRequest
        request.url = self.resolve(clientRequest.url)
        request.timeout = min(clientRequest.timeout, self.options.timeout)

        // Don't use VaporHTTPClient here - that doesn't work if the `HTTPClient` trait is
        // disabled
        let response = try await AHCClient(
            http: self.http, contentConfiguration: self.contentConfiguration,
            decodesCompressedBodies: self.decodesCompressedBodies
        ).send(request)
        self.unreadBodies.track(response.body)
        return response
    }

    func withOptions<T>(_ options: LiveClientOptions, _ body: (any TestClient) async throws -> T) async throws -> T {
        try await Self.withClient(app: self.app, address: self.address, options: options, body)
    }

    /// Runs `body` with a client for the server at `address`, owning the `HTTPClient` it needs.
    static func withClient<T>(
        app: Application,
        address: SocketAddress,
        options: LiveClientOptions,
        _ body: (LiveTestClient) async throws -> T
    ) async throws -> T {
        guard let configuration = options.httpClientConfiguration else {
            // The shared client is configured like a browser, which includes decoding gzip and deflate.
            let client = LiveTestClient(
                app: app, address: address, options: options, http: .shared, decodesCompressedBodies: true)
            let result = try await body(client)
            await client.unreadBodies.drain()
            return result
        }

        let http = HTTPClient(
            eventLoopGroup: MultiThreadedEventLoopGroup.singleton,
            configuration: configuration,
            backgroundActivityLogger: Logger.current
        )
        let decodesCompressedBodies: Bool
        if case .enabled = configuration.decompression {
            decodesCompressedBodies = true
        } else {
            decodesCompressedBodies = false
        }
        let client = LiveTestClient(
            app: app, address: address, options: options, http: http, decodesCompressedBodies: decodesCompressedBodies)
        do {
            let result = try await body(client)
            await client.unreadBodies.drain()
            try await http.shutdown()
            return result
        } catch {
            try? await http.shutdown()
            throw error
        }
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
