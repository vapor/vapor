import VaporTesting
import Testing
import Vapor
import NIOCore

@Suite("Password Tests")
struct PasswordTests {
    #if bcrypt
    @Test("Test BCrypt application password")
    func testBCryptApplicationPassword() async throws {
        try await withApp(services: .init(passwordHasher: .provided(BcryptHasher(cost: 4)))) { app in
            let hash = try await app.passwordHasher.hash("vapor")
            #expect(hash != "vapor") // BCrypt should not return the plaintext password
            let verify = try await app.passwordHasher.verify("vapor", created: hash)
            #expect(verify == true)
        }
    }
    #endif

    @Test("Test plaintext application password")
    func testPlaintextApplicationPassword() async throws {
        try await withApp(services: .init(passwordHasher: .provided(PlaintextHasher()))) { app in
            let hash = try await app.passwordHasher.hash("vapor")
            #expect(hash == "vapor") // Should be the same as plaintext
            let verify = try await app.passwordHasher.verify("vapor", created: hash)
            #expect(verify == true)
        }
    }

    @Test("Test application default password")
    func testUsesProvider() async throws {
        try await withApp { app in
            let hash = try await app.passwordHasher.hash("vapor")
            #if bcrypt
            #expect(hash != "vapor") // Defaults to BCrypt so should not match
            #else
            #expect(hash == "vapor") // Defaults to Plaintext so should match
            #endif
            let verify = try await app.passwordHasher.verify("vapor", created: hash)
            #expect(verify == true)
        }
    }
}
