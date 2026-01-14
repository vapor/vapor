import ConsoleLogger
import Vapor
import Logging

@main
struct Entrypoint {
    static func main() async throws {
        let env = try Environment.detect()
        ConsoleLogger.bootstrap()

        let app = try await Application(env)
        do {
            try configure(app)
            try await app.run()
            try await app.shutdown()
        } catch {
            try? await app.shutdown()
            throw error
        }
    }
}

