import Vapor
import Logging

@main
struct Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        let app = Application(env)
        defer { app.shutdown() }

        try configure(app)
        // TODO: Replace with correctly async version of `app.run()`.
        try app.start()
        try await app.running?.onStop.get()
    }
}

