import VaporTesting
import Testing
import Vapor
import NIOCore

@Suite("Password Tests")
struct PasswordTests {
    @Test("Test BCrypt application password")
    func testBCryptApplicationPassword() async throws {
        let appliation = try await Application(.testing, services: .init(passwordHasher: BcryptHasher(cost: 4)))
            let hash = try await appliation.passwordHasher.hash("vapor")
            #expect(hash != "vapor") // BCrypt should not return the plaintext password
            let verify = try await appliation.passwordHasher.verify("vapor", created: hash)
            #expect(verify == true)
        try await appliation.shutdown()
    }

    @Test("Test plaintext application password")
    func testPlaintextApplicationPassword() async throws {
        let appliation = try await Application(.testing, services: .init(passwordHasher: PlaintextHasher()))
        let hash = try await appliation.passwordHasher.hash("vapor")
        #expect(hash == "vapor") // Should be the same as plaintext
        let verify = try await appliation.passwordHasher.verify("vapor", created: hash)
        #expect(verify == true)
        try await appliation.shutdown()
    }

    @Test("Test application default password")
    func testUsesProvider() async throws {
        try await withApp { app in
            let hash = try await app.passwordHasher.hash("vapor")
            #expect(hash != "vapor") // Defaults to BCrypt so should not match
            let verify = try await app.passwordHasher.verify("vapor", created: hash)
            #expect(verify == true)
        }
    }
}
