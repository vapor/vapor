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
        var logger = Logger(label: "codes.vapor.app")
        logger.logLevel = .debug
        return try await withLogger(logger) { _ in
            let app = try await Application(configReader: config)
            do {
                try await configure(app)
                try await app.run()
                try await app.shutdown()
            } catch {
                try? await app.shutdown()
                throw error
            }
        }
    }
}

