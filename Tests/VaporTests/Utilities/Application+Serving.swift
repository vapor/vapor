import Vapor
import RoutingKit

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
