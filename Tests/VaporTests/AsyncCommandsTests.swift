import ConsoleKit
import XCTest
import Vapor

final class AsyncCommandsTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
    }
    
    override func tearDown() async throws {
        try await app.asyncShutdown()
    }
    
    func testAsyncCommands() async throws {
        app.asyncCommands.use(FooCommand(), as: "foo")

        app.environment.arguments = ["vapor", "foo", "bar"]

        try await app.startup()

        XCTAssertTrue(app.storage[TestStorageKey.self] ?? false)
    }
}

extension AsyncCommandsTests {
    struct TestStorageKey: StorageKey {
        typealias Value = Bool
    }

    struct FooCommand: AsyncCommand {
        struct Signature: CommandSignature {
            @Argument(name: "name")
            var name: String
        }

        let help = "Does the foo."

        func run(using context: CommandContext, signature: Signature) throws {
            context.application.storage[TestStorageKey.self] = true
        }
    }
}
