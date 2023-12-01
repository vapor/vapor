import XCTest
import Vapor

final class AsyncCommandsTests: XCTestCase {
    func testAsyncCommands() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.asyncCommands.use(FooCommand(), as: "foo")

        app.environment.arguments = ["vapor", "foo", "bar"]

        XCTAssertNoThrow(try app.start())

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
