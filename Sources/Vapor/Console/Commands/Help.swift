/**
    Prints out information about the
    available commands including their
    identifiers and help messages.
*/
public struct Help: Command {
    public static let id = "help"
    public let app: Application

    public init(app: Application) {
        self.app = app
    }

    public func run() {
        print("Available Commands: ")

        let commands = app.commands.filter { command in
            return command.id != Help.id
        }
        
        commands.forEach { command in
            let signature = command.signature(leading: "  ")
            print(signature)

            command.help.forEach { line in
                print("    " + line)

            }
        }
    }
}
