@testable import Vapor
import XCTVapor
import COperatingSystem

final class EnvironmentSecretTests: XCTestCase {
    func testNonExistingSecretFile() throws {
        let folder = #file.split(separator: "/").dropLast().joined(separator: "/")
        let path = "/" + folder + "/Utilities/non-existing-secret"

        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        let eventLoop = app.eventLoopGroup.next()
        let secretContent = try! Environment.secret(path: path, fileIO: app.fileio, on: eventLoop).wait()
        XCTAssertNil(secretContent)
    }

    func testExistingSecretFile() throws {
        let folder = #file.split(separator: "/").dropLast().joined(separator: "/")
        let path = "/" + folder + "/Utilities/my-secret-env-content"

        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        let eventLoop = app.eventLoopGroup.next()
        let secretContent = try! Environment.secret(path: path, fileIO: app.fileio, on: eventLoop).wait()
        XCTAssertEqual(secretContent, "password")
    }

    func testExistingSecretFileFromEnvironmentKey() throws {
        let folder = #file.split(separator: "/").dropLast().joined(separator: "/")
        let path = "/" + folder + "/Utilities/my-secret-env-content"

        let key = "MY_ENVIRONMENT_SECRET"
        setenv(key, path, 1)
        let app = Application(.detect(default: .testing))
        defer {
            app.shutdown()
            unsetenv(key)
        }

        let eventLoop = app.eventLoopGroup.next()
        let secretContent = try! Environment.secret(key: key, fileIO: app.fileio, on: eventLoop).wait()
        XCTAssertEqual(secretContent, "password")
    }

    func testLoadingSecretFromEnvKeyWhichDoesNotExist() throws {
        let key = "MY_NON_EXISTING_ENVIRONMENT_SECRET"
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        let eventLoop = app.eventLoopGroup.next()
        let secretContent = try! Environment.secret(key: key, fileIO: app.fileio, on: eventLoop).wait()
        XCTAssertNil(secretContent)
    }
}
