public protocol Responder: Sendable {
    func respond(to request: Request) async throws -> Response
}

extension Application {
    package func makeResponder() -> any Responder {
        switch self.responder {
        case .default:
            return DefaultResponder(
                routes: self.routes,
                middleware: self.middleware.resolve(),
            )
        case .provided(let provided):
            return provided
        }
    }
}
