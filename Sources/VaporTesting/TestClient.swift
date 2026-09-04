@testable public import Vapor
import Foundation
#warning("Migrate to our own SocketAddress")
import NIOCore
import AsyncHTTPClient

public protocol TestClient: Client {
    var baseURL: URI? { get }
}

struct InMemoryTestClient: TestClient {
    let app: Application
    let responder: any Responder
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

        var response = try await self.responder.respond(to: request)
        return ClientResponse(
            status: response.status,
            headers: response.headers,
            body: .init(data: try await response.body.collect() ?? Data()),
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

        // Collected before handing back, as the in-memory client does: a test that only asserts on
        // headers would otherwise drop the body unread, which cancels the request mid-write and
        // shows up as a spurious failure in a streaming handler. Built fresh rather than assigned
        // through `body`'s `didSet`, so a HEAD response keeps the `Content-Length` it advertised.
        return ClientResponse(
            status: response.status,
            headers: response.headers,
            body: try await ResponseBodyCollection.collect.apply(to: response.body),
            maxBodySize: clientRequest.maxResponseBodySize,
            contentConfiguration: self.contentConfiguration
        )
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
        return URI(
            scheme: base.scheme,
            host: base.host,
            port: base.port,
            path: url.path,
            query: url.query,
            fragment: url.fragment
        )
    }
}
