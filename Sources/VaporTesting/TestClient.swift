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
        let request = Request(
            method: clientRequest.method,
            url: clientRequest.url,
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
//    let options: LiveClientOptions
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
        request.url = clientRequest.url
//        request.timeout = self.options.timeout

        return try await VaporHTTPClient(http: self.http, contentConfiguration: self.contentConfiguration)
            .send(request)
    }
}
