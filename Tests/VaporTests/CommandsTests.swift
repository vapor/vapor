import ConsoleKit
import Vapor
import VaporTesting
import Testing

@Suite("Command Tests")
struct CommandTests {
    @Test("Test a command runs correctly")
    func vaporCommand() async throws {
        try await withApp { app in
            app.asyncCommands.use(FooCommand(), as: "foo")

            app.environment.arguments = ["vapor", "foo", "bar"]

            try await app.startup()

            #expect(app.storage[TestStorageKey.self] ?? false == true)
        }
    }
}

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
