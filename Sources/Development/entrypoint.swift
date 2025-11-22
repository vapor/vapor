import Configuration
import Vapor
import Logging

@main
struct Entrypoint {
    static func main() async throws {
        let config = ConfigReader(providers: [
                // The `CommandLineArgumentsProvider` requires the `CommandLineArgumentsSupport` package trait
                // CommandLineArgumentsProvider(),
                EnvironmentVariablesProvider(),
            ]
        )
        let env = try Environment.detect(from: config)
        try LoggingSystem.bootstrap(from: config)

        let app = try await Application(env, configReader: config)
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

