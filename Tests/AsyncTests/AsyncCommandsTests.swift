import XCTest
import Vapor

final class AsyncCommandsTests: XCTestCase {
    func testAsyncCommands() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        struct FooCommand: AsyncCommand {
            struct Signature: CommandSignature {
                @Argument(name: "name")
                var name: String
            }

            let help = "Does the foo."

            func run(using context: CommandContext, signature: Signature) throws {
                context.console.output("Hello, \(signature.name)!")
            }
        }

        app.asyncCommands.use(FooCommand(), as: "foo")

        app.environment.arguments = ["vapor", "foo", "bar"]

        XCTAssertNoThrow(try app.start())
    }
}
