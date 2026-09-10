public protocol Responder: Sendable {
    func respond(to request: Request) async throws -> Response
}

extension Application {
    package func makeResponder() -> any Responder {
        self.serverContext.makeResponder()
    }
}
