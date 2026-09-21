public protocol Responder: Sendable {
    func respond(to request: Request) async throws -> Response
}

extension Application {
    package func makeResponder() -> any Responder {
        self.serverContext.makeResponder()
    }

    /// Builds the configured responder for benchmarks without exposing it as application API.
    @_spi(Benchmarking)
    public func makeBenchmarkResponder() -> any Responder {
        self.makeResponder()
    }
}
