@testable import Vapor
import Testing
import VaporTesting
import Foundation

@Suite("Environment Secret Tests")
struct EnvironmentSecretTests {
    @Test("Non-existing secret file")
    func testNonExistingSecretFile() async throws {
        let folder = #filePath.split(separator: "/").dropLast().joined(separator: "/")
        let path = "/" + folder + "/Utilities/non-existing-secret"

        let secretContent = try await Environment.secret(path: path)
        #expect(secretContent == nil)
    }

    @Test("Existing secret file")
    func testExistingSecretFile() async throws {
        let folder = #filePath.split(separator: "/").dropLast().joined(separator: "/")
        let path = "/" + folder + "/Utilities/my-secret-env-content"

        let secretContent = try await Environment.secret(path: path)
        #expect(secretContent == "password")
    }

    @Test("Existing secret file from environment key")
    func testExistingSecretFileFromEnvironmentKey() async throws {
        let folder = #filePath.split(separator: "/").dropLast().joined(separator: "/")
        let path = "/" + folder + "/Utilities/my-secret-env-content"

        let key = "MY_ENVIRONMENT_SECRET"
        setenv(key, path, 1)
        defer {
            unsetenv(key)
        }

        let secretContent = try await Environment.secret(key: key)
        #expect(secretContent == "password")
    }

    @Test("Loading secret from environment key which does not exist")
    func testLoadingSecretFromEnvKeyWhichDoesNotExist() async throws {
        let key = "MY_NON_EXISTING_ENVIRONMENT_SECRET"
        let secretContent = try await Environment.secret(key: key)
        #expect(secretContent == nil)
    }
}
