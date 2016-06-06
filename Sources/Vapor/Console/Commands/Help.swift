/**
    Prints out information about the
    available commands including their
    identifiers and help messages.
*/
public struct Help: Command {
    public let id: String
    public let app: Application

    public init(app: Application) {
        id = "help"
        self.app = app
    }

    public func run() {
        print("Available Commands: ")

        let commands = app.commands.filter { command in
            return command.id != self.id
        }
        
        commands.forEach { command in
            command.printSignature(leading: "  ")

            command.help.forEach { line in
                print("    " + line)

            }
        }
    }
}
