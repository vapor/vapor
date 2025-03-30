import XCTVapor
import XCTest
import Vapor
import NIOCore

final class PasswordTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    func testSyncBCryptService() throws {
        let hash = try app.password.hash("vapor")
        XCTAssertTrue(try BCryptDigest().verify("vapor", created: hash))
        
        let result = try app.password.verify("vapor", created: hash)
        XCTAssertTrue(result)
    }
    
    func testSyncPlaintextService() throws {
        app.passwords.use(.plaintext)
        
        let hash = try app.password.hash("vapor")
        XCTAssertEqual(hash, "vapor")
        
        let result = try app.password.verify("vapor", created: hash)
        XCTAssertTrue(result)
    }
    
    func testAsyncBCryptRequestPassword() throws {
        try assertAsyncRequestPasswordVerifies(.bcrypt, on: app)
    }
    
    func testAsyncPlaintextRequestPassword() throws {
        try assertAsyncRequestPasswordVerifies(.plaintext, on: app)
    }
    
    func testAsyncBCryptApplicationPassword() throws {
        try assertAsyncApplicationPasswordVerifies(.bcrypt, on: app)
    }
    
    func testAsyncPlaintextApplicationPassword() throws {
        try assertAsyncApplicationPasswordVerifies(.plaintext, on: app)
    }
    
    func testAsyncUsesProvider() throws {
        app.passwords.use(.plaintext)
        let hash = try app.password.async(
            on: app.threadPool,
            hopTo: app.eventLoopGroup.next()
        ).hash("vapor").wait()
        XCTAssertEqual(hash, "vapor")
    }

    func testAsyncApplicationDefault() throws {
        app.passwords.use(.plaintext)
        let hash = try app.password.async.hash("vapor").wait()
        XCTAssertEqual(hash, "vapor")
    }
    
    private func assertAsyncApplicationPasswordVerifies(
        _ provider: Application.Passwords.Provider,
        on app: Application,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        app.passwords.use(provider)
        
        let asyncHash = try app.password
            .async(on: app.threadPool, hopTo: app.eventLoopGroup.next())
            .hash("vapor")
            .wait()
        
        let asyncVerify = try app.password
            .async(on: app.threadPool, hopTo: app.eventLoopGroup.next())
            .verify("vapor", created: asyncHash)
            .wait()
        
        XCTAssertTrue(asyncVerify, file: file, line: line)
    }
    
    private func assertAsyncRequestPasswordVerifies(
        _ provider: Application.Passwords.Provider,
        on app: Application,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        app.passwords.use(provider)
        
        app.get("test") { req -> EventLoopFuture<String> in
            return req.password
                .async
                .hash("vapor")
                .flatMap { digest -> EventLoopFuture<Bool> in
                    return req.password
                        .async
                        .verify("vapor", created: digest)
                   
            }
            .map { $0 ? "true" : "false" }
        }
        
        try app.test(.GET, "test", afterResponse: { res in
            XCTAssertEqual(res.body.string, "true", file: file, line: line)
        })
    }
}
