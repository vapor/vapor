import Vapor
import RoutingKit
import ServiceLifecycle
import Testing

/// Starts an application, waits until it is serving, then runs `task` on it.
func whileServing(_ task: (Application) -> Void) async throws {
    let app = try await Application(.testing)
    app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
    app.get("hello") { _ in "world" }

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask { try? await app.run() }
        // Bound means startup has read its configuration.
        _ = try await app.server.listeningAddress
        task(app)
        group.cancelAll()
    }
    try await app.shutdown()
}

/// Runs `app`'s server on an ephemeral IPv4 port for the duration of `body`, handing it the port.
///
/// For tests that talk to the server with something VaporTesting's client can't stand in for - a
/// streaming upload, an AsyncHTTPClient delegate, a negotiated HTTP version. Anything else should
/// use `app.testing(.running)`.
func withRunningServer<T>(_ app: Application, _ body: (Int) async throws -> T) async throws -> T {
    app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
    try await app.boot()

    return try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask { try await app.server.run() }

        let result: T
        do {
            let port = try #require(await app.server.listeningAddress.port)
            result = try await body(port)
        } catch {
            group.cancelAll()
            throw error
        }

        group.cancelAll()
        do {
            try await group.waitForAll()
        } catch is CancellationError {
            // How the server stops when its task is cancelled, not a failure.
        }
        return result
    }
}
