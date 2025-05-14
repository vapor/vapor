import Vapor

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
    configure: ((Application) async throws -> Void)? = nil,
    _ test: (Application) async throws -> T
) async throws -> T {
    let app = try await Application.make(.testing)
    let result: T
    do {
        try await configure?(app)
        result = try await test(app)
    } catch {
        try? await app.asyncShutdown()
        throw error
    }
    try await app.asyncShutdown()
    return result
}
