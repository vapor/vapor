import Configuration
import ConsoleLogger
import Vapor
import Logging

@main
struct Entrypoint {
    static func main() async throws {
        let config = ConfigReader(providers: [
                CommandLineArgumentsProvider(),
                EnvironmentVariablesProvider(),
            ]
        )
        ConsoleLogger.bootstrap(config: config)

        let app = try await Application(configReader: config)
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

