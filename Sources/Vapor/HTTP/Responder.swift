public protocol Responder: Sendable {
    func respond(to request: Request) async throws -> Response
}

extension Application {
    /// Builds the configured responder after routes and middleware have been registered.
    public func makeResponder() -> any Responder {
        self.serverContext.makeResponder()
    }
}
