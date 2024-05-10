import XCTVapor
import XCTest
import Vapor

final class AsyncPasswordTests: XCTestCase {
    func testAsyncBCryptRequestPassword() async throws {
        let test = Environment(name: "testing", arguments: ["vapor"])
        let app = await Application(test)
        defer { app.shutdown() }

        try await assertAsyncRequestPasswordVerifies(.bcrypt, on: app)
    }

    func testAsyncPlaintextRequestPassword() async throws {
        let test = Environment(name: "testing", arguments: ["vapor"])
        let app = await Application(test)
        defer { app.shutdown() }

        try await assertAsyncRequestPasswordVerifies(.plaintext, on: app)
    }

    func testAsyncBCryptApplicationPassword() async throws {
        let test = Environment(name: "testing", arguments: ["vapor"])
        let app = await Application(test)
        defer { app.shutdown() }

        try await assertAsyncApplicationPasswordVerifies(.bcrypt, on: app)
    }

    func testAsyncPlaintextApplicationPassword() async throws {
        let test = Environment(name: "testing", arguments: ["vapor"])
        let app = await Application(test)
        defer { app.shutdown() }

        try await assertAsyncApplicationPasswordVerifies(.plaintext, on: app)
    }

    func testAsyncUsesProvider() async throws {
        let test = Environment(name: "testing", arguments: ["vapor"])
        let app = await Application(test)
        defer { app.shutdown() }
        app.passwords.use(.plaintext)
        let hash = try await app.password.async(
            on: app.threadPool,
            hopTo: app.eventLoopGroup.next()
        ).hash("vapor")
        XCTAssertEqual(hash, "vapor")
    }

    func testAsyncApplicationDefault() async throws {
        let test = Environment(name: "testing", arguments: ["vapor"])
        let app = await Application(test)
        defer { app.shutdown() }
        app.passwords.use(.plaintext)
        let hash = try await app.password.async.hash("vapor")
        XCTAssertEqual(hash, "vapor")
    }

    private func assertAsyncApplicationPasswordVerifies(
        _ provider: Application.Passwords.Provider,
        on app: Application,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        app.passwords.use(provider)

        let asyncHash = try await app.password
            .async(on: app.threadPool, hopTo: app.eventLoopGroup.next())
            .hash("vapor")

        let asyncVerify = try await app.password
            .async(on: app.threadPool, hopTo: app.eventLoopGroup.next())
            .verify("vapor", created: asyncHash)

        XCTAssertTrue(asyncVerify, file: file, line: line)
    }

    private func assertAsyncRequestPasswordVerifies(
        _ provider: Application.Passwords.Provider,
        on app: Application,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        app.passwords.use(provider)

        app.get("test") { req async throws -> String in
            let digest = try await req.password.async.hash("vapor")
            let result = try await req.password.async.verify("vapor", created: digest)
            return result ? "true" : "false"
        }

        try await app.test(.GET, "test", afterResponse: { res async in
            XCTAssertEqual(res.body.string, "true", file: file, line: line)
        })
    }
}
