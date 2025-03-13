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
public func withApp(address: BindAddress? = nil, _ block: (Application) async throws -> Void) async throws {
    let app = try await Application(.testing)
    do {
        try await block(app)
    } catch {
        try? await app.shutdown()
        throw error
    }
    try await app.shutdown()
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
public func withRunningApp(app: Application, portToUse: Int = 0, _ block: (Int) async throws -> Void) async throws {
    return try await withThrowingTaskGroup(of: Void.self) { group in
        app.serverConfiguration.address = .hostname("localhost", port: portToUse)
        let portPromise = Promise<Int>()
        app.serverConfiguration.onServerRunning = { channel in
            guard let port = channel.localAddress?.port else {
                portPromise.fail(TestErrors.portNotSet)
                return
            }
            portPromise.complete(port)
        }
        group.addTask {
            app.logger.info("Will attempt to start server")
            try await app.server.start()
        }

        do {
            try await block(try await portPromise.wait())
            try await app.server.shutdown()
        } catch {
            try? await app.server.shutdown()
            throw error
        }
    }
}
