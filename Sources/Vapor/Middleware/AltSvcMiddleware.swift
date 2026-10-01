import HTTPTypes

/// A middleware that adds the [`Alt-Svc`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Alt-Svc) header to advertise available HTTP versions.
public struct AltSvcMiddleware: Middleware {
    private let serverConfiguration: ServerConfiguration

    public init(serverConfiguration: ServerConfiguration) {
        self.serverConfiguration = serverConfiguration
    }

    public func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        var response = try await next.respond(to: request)
        guard let port = self.serverConfiguration.port else {
            return response
        }
        var altSvcHeaderValue = ""
        for version in self.serverConfiguration.httpVersions.sorted().reversed() {
            altSvcHeaderValue += "\(version.alpnProtocolID)=\":\(port)\", "
        }
        if !altSvcHeaderValue.isEmpty {
            altSvcHeaderValue.removeLast(2)  // Remove the trailing ", "
            response.headers[.altSvc] = altSvcHeaderValue
        }
        return response
    }
}
