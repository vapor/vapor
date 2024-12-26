import Vapor

/// Perform a test while handling lifecycle of the application.
/// Feel free to create a custom function like this, tailored to your project.
///
/// Usage:
/// ```swift
/// @Test
/// func helloWorld() async throws {
///     try await withApp(/* whatever set up needed*/) { app in
///         try await self.app.testing().test(.GET, "hello", afterResponse: { res async in
///             #expect(res.status == .ok)
///             #expect(res.body.string == "Hello, world!")
///         })
///     }
/// }
/// ```
public func withApp<T>(_ block: (Application) async throws -> T) async throws -> T {
    let app = try await Application.make(.testing)
    let result = try await block(app)
    try await app.asyncShutdown()
    return result
}
