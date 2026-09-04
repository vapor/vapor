public import Vapor
import Foundation

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
