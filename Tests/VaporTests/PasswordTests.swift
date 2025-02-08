import VaporTesting
import Testing
import Vapor
import NIOCore

@Suite("Password Tests")
struct PasswordTests {

    @Test("Test synchronous BCrypt service")
    func syncBCryptService() async throws {
        try await withApp { app in
            let hash = try app.password.hash("vapor")
            #expect(try BCryptDigest().verify("vapor", created: hash) == true)

            let result = try app.password.verify("vapor", created: hash)
            #expect(result == true)
        }
    }

    @Test("Test synchronous plaintext service")
    func syncPlaintextService() async throws {
        try await withApp { app in
            app.passwords.use(.plaintext)

            let hash = try app.password.hash("vapor")
            #expect(hash == "vapor")

            let result = try app.password.verify("vapor", created: hash)
            #expect(result == true)
        }
    }

    @Test("Test asynchronous BCrypt service")
    func testAsyncBCryptRequestPassword() async throws {
        try await assertAsyncRequestPasswordVerifies(.bcrypt)
    }

    @Test("Test asynchronous plaintext service")
    func testAsyncPlaintextRequestPassword() async throws {
        try await assertAsyncRequestPasswordVerifies(.plaintext)
    }

    @Test("Test asynchronous BCrypt application password")
    func testAsyncBCryptApplicationPassword() async throws {
        try await assertAsyncApplicationPasswordVerifies(.bcrypt)
    }

    @Test("Test asynchronous plaintext application password")
    func testAsyncPlaintextApplicationPassword() async throws {
        try await assertAsyncApplicationPasswordVerifies(.plaintext)
    }

    @Test("Test asynchronous application default password")
    func testAsyncUsesProvider() async throws {
        try await withApp { app in
            app.passwords.use(.plaintext)
            let hash = try await app.password.async(
                on: app.threadPool,
                hopTo: app.eventLoopGroup.next()
            ).hash("vapor")
            #expect(hash == "vapor")
        }
    }

    @Test("Test asynchronous application default password")
    func testAsyncApplicationDefault() async throws {
        try await withApp { app in
            app.passwords.use(.plaintext)
            let hash = try await app.password.async.hash("vapor")
            #expect(hash == "vapor")
        }
    }
    
    private func assertAsyncApplicationPasswordVerifies(
        _ provider: Application.Passwords.Provider,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        try await withApp { app in
            app.passwords.use(provider)

            let asyncHash = try await app.password
                .async(on: app.threadPool, hopTo: app.eventLoopGroup.next())
                .hash("vapor")

            let asyncVerify = try await app.password
                .async(on: app.threadPool, hopTo: app.eventLoopGroup.next())
                .verify("vapor", created: asyncHash)

            #expect(asyncVerify == true, sourceLocation: sourceLocation)
        }
    }
    
    private func assertAsyncRequestPasswordVerifies(
        _ provider: Application.Passwords.Provider,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        try await withApp { app in
            app.passwords.use(provider)

            app.get("test") { req async throws -> String in
                let digest = try await req.password.async.hash("vapor")
                let verify = try await req.password.async.verify("vapor", created: digest)
                return verify ? "true" : "false"
            }

            try await app.testing().test(.GET, "test", afterResponse: { res in
                #expect(res.body.string == "true", sourceLocation: sourceLocation)
            })
        }
    }
}
