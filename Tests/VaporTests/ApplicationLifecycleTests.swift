import Vapor
import Testing
import VaporTesting
import HTTPTypes
import Logging

/// Covers what `run()` does to the application when it fails.
///
/// Both in-tree callers (`Development`'s entrypoint and `withApp`) shut the application down in
/// their own `catch`, so these paths went unnoticed: a caller that trusts `run()` to clean up — as
/// its signature implies — was left with lifecycle handlers never shut down, storage never
/// released, and `deinit`'s `didShutdown` assertion firing on release.
@Suite("Application Lifecycle On Failure")
struct ApplicationLifecycleTests {
    /// Records which lifecycle hooks ran, and can fail the boot on demand.
    final class RecordingHandler: LifecycleHandler, @unchecked Sendable {
        private(set) var shutdownRan = false
        private let failBoot: Bool

        init(failBoot: Bool = false) {
            self.failBoot = failBoot
        }

        func willBoot(_ application: Application) async throws {
            if self.failBoot {
                throw Abort(.internalServerError, reason: "willBoot failed")
            }
        }

        func shutdown(_ application: Application) async {
            self.shutdownRan = true
        }
    }

    @Test("A server that fails to start still shuts the application down", .timeLimit(.minutes(1)))
    func testShutsDownWhenServerFailsToStart() async throws {
        let app = try await Application(.testing)
        let handler = RecordingHandler()
        app.lifecycle.use(handler)
        app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
        // Certificate paths that do not resolve fail the server after boot, inside the services.
        app.serverConfiguration.tlsConfiguration = .pemFile(
            certificateChainPath: "/nonexistent/certificate.crt",
            privateKeyPath: "/nonexistent/private.key"
        )

        await #expect(throws: (any Error).self) {
            try await app.run()
        }

        #expect(app.didShutdown, "run() must shut the application down before rethrowing")
        #expect(handler.shutdownRan, "lifecycle handlers must be told to shut down")
    }

    @Test("A lifecycle handler that fails to boot still shuts the application down", .timeLimit(.minutes(1)))
    func testShutsDownWhenBootFails() async throws {
        let app = try await Application(.testing)
        let handler = RecordingHandler(failBoot: true)
        app.lifecycle.use(handler)

        await #expect(throws: (any Error).self) {
            try await app.run()
        }

        // `boot()` used to run outside the `do`, so this failure was neither reported nor cleaned up.
        #expect(app.didShutdown, "run() must shut the application down before rethrowing")
        #expect(handler.shutdownRan, "lifecycle handlers must be told to shut down")
    }
}
