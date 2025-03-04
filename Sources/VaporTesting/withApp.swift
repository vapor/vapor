import Vapor

/// Perform a test while handling lifecycle of the application. Returns the result of the block
/// Feel free to create a custom function like this, tailored to your project.
///
/// Usage:
/// ```swift
/// @Test
/// func helloWorld() async throws {
///     let status = try await withAppResult { app in
///         app.get("hello") { req -> String in
///             return "Hello, world!"
///         }
///
///         let result: HTTPStatus? = nil
///         try await app.testing().test(.get, "hello", afterResponse: { res async in
///             #expect(res.status == .ok)
///             result = res.status
///             #expect(res.body.string == "Hello, world!")
///         })
///         return result
///     }
/// }
/// ```
public func withAppResult<T>(_ block: (Application) async throws -> T) async throws -> T {
    let app = try await Application(.testing)
    let result: T
    do {
        result = try await block(app)
    } catch {
        try? await app.shutdown()
        throw error
    }
    try await app.shutdown()
    return result
}

/// Perform a test while handling lifecycle of the application.
/// Feel free to create a custom function like this, tailored to your project.
///
/// Usage:
/// ```swift
/// @Test
/// func helloWorld() async throws {
///     try await withApp { app in
///         app.get("hello") { req -> String in
///             return "Hello, world!"
///         }
///
///         try await app.testing().test(.get, "hello", afterResponse: { res async in
///             #expect(res.status == .ok)
///             #expect(res.body.string == "Hello, world!")
///         })
///     }
/// }
/// ```
public func withApp(_ block: (Application) async throws -> Void) async throws {
    let app = try await Application(.testing)
    do {
        try await block(app)
    } catch {
        try? await app.shutdown()
        throw error
    }
    try await app.shutdown()
}
