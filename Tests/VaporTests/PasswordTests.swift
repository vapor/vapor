import VaporTesting
import Testing
import Vapor
import NIOCore

@Suite("Password Tests")
struct PasswordTests {
    @Test("Test BCrypt application password")
    func testBCryptApplicationPassword() async throws {
        try await assertApplicationPasswordVerifies(.bcrypt)
    }

    @Test("Test plaintext application password")
    func testPlaintextApplicationPassword() async throws {
        try await assertApplicationPasswordVerifies(.plaintext)
    }

    @Test("Test application default password")
    func testUsesProvider() async throws {
        try await withApp { app in
            app.passwords.use(.plaintext)
            let hash = try await app.password.hasher.hash("vapor")
            #expect(hash == "vapor")
        }
    }

    @Test("Test application default password")
    func testApplicationDefault() async throws {
        try await withApp { app in
            app.passwords.use(.plaintext)
            let hash = try await app.password.hasher.hash("vapor")
            #expect(hash == "vapor")
        }
    }
    
    private func assertApplicationPasswordVerifies(
        _ provider: Application.Passwords.Provider,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        try await withApp { app in
            app.passwords.use(provider)

            let hash = try await app.password.hasher.hash("vapor")
            let verify = try await app.password.hasher.verify("vapor", created: hash)

            #expect(verify == true, sourceLocation: sourceLocation)
        }
    }
}
