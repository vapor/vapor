import Configuration
import Vapor
import NIOCore
import NIOConcurrencyHelpers
import ServiceLifecycle
@testable import CoreMetrics
@testable import Instrumentation

/// Perform a test while handling lifecycle of the application.
/// Feel free to create a custom function like this, tailored to your project.
///
/// Usage:
/// ```swift
/// @Test
/// func helloWorld() async throws {
///     try await withApp(configure: configure) { app in
///         try await app.testing().test(.GET, "hello", afterResponse: { res async in
///             #expect(res.status == .ok)
///             #expect(res.body.string == "Hello, world!")
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
    address: BindAddress? = nil,
    configReader: ConfigReader = ConfigReader(providers: [CommandLineArgumentsProvider(), EnvironmentVariablesProvider()]),
    services: Application.ServiceConfiguration = .init(),
    configure: ((Application) async throws -> Void)? = nil,
    _ test: (Application) async throws -> T
) async throws -> T {
    MetricsSystem.bootstrapInternal(TaskLocalMetricsSystemWrapper())
    InstrumentationSystem.bootstrapInternal(TaskLocalTracingSystemWrapper())
    let app = try await Application(.testing, configReader: configReader, services: services)
    if let address {
        app.serverConfiguration.address = address
    }
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

/// Run code with a live running app. This will start the server, retrieve the allocated port and run the block of code.
/// Useful when you need a live server but don't want to manually manage the lifecycle.
///
/// Usage:
/// ```swift
/// @Test
/// func testRequest() async throws {
///    try await withApp { app in
///        app.get("hello") { req -> String in
///            return "Hello, world!"
///        }
///
///        try await withRunningApp(app: app) { port in
///            let res = try await app.client.get("http://localhost:\(port)/hello")
///            #expect(res.status == .ok)
///            #expect(res.body.string == "Hello, world!")
///        }
///    }
/// }
/// ```
public func withRunningApp<T: Sendable>(app: Application, hostname: String = "localhost", portToUse: Int = 0, _ block: (Int) async throws -> T) async throws -> T {
    app.serverConfiguration.address = .hostname(hostname, port: portToUse)
    try await app.boot()

    return try await withThrowingTaskGroup(of: T?.self) { group in
        // Run the server in a child task
        group.addTask {
            try await app.server.run()
            return nil
        }

        // Wait for the server to bind and report its address
        let address = try await app.server.listeningAddress
        guard let port = address.port else {
            group.cancelAll()
            throw TestErrors.portNotSet
        }

        // Run the test block
        let result = try await block(port)

        // Cancel the server task (triggers graceful shutdown)
        group.cancelAll()
        return result
    }!
}
