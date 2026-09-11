public import Configuration
public import Vapor
import ServiceLifecycle
@testable import CoreMetrics
@testable import Instrumentation
public import Logging

/// Perform a test while handling lifecycle of the application.
/// Feel free to create a custom function like this, tailored to your project.
///
/// Usage:
/// ```swift
/// @Test
/// func helloWorld() async throws {
///     try await withApp(configure: configure) { app in
///         try await app.testing { client in
///             let res = try await client.get("hello")
///             #expect(res.status == .ok)
///             try #expect(await res.body.requireString() == "Hello, world!")
///         })
///     }
/// }
/// ```
///
/// - Parameters:
///   - configure: A closure where you can register routes, databases, providers, and more.
///   - test: A closure which performs your actual test with the configured application.
@discardableResult
public func withApp<T>(
    environment: Environment = .testing,
    configuration: ServerConfiguration = .init(),
    configReader: ConfigReader = ConfigReader(providers: [CommandLineArgumentsProvider(), EnvironmentVariablesProvider()]),
    logger: Logger = Logger.current,
    services: Application.ServiceConfiguration = .init(),
    configure: ((Application) async throws -> Void)? = nil,
    _ test: (Application) async throws -> T
) async throws -> T {
    MetricsSystem.bootstrapInternal(TaskLocalMetricsSystemWrapper())
    InstrumentationSystem.bootstrapInternal(TaskLocalTracingSystemWrapper())
    return try await withLogger(logger) { _ in
        let app = try await Application(environment, configuration: configuration, configReader: configReader, services: services)
        let result: T
        do {
            try await configure?(app)
            result = try await test(app)
        } catch {
            try? await app.shutdown()
            throw error
        }
        try await app.shutdown()
        return result
    }
}
