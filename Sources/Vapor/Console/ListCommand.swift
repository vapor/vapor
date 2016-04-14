/// Lists all available commands registered with Console
public class ListCommand: Command {

    /// Console this command is registered to
    public let console: Console

    /// Name of the command
    public let name = "list"

    /// Optional help info for the command
    public let help: String? = "Lists all available commands"

    /**
        Initialize the command
        - parameter console: Console instance this command will be registered on
    */
    public required init(console: Console) {
        self.console = console
    }

    /**
        Called by `run()` after input has been compiled
        - parameter input: CLI input
        - throws: Console.Error
    */
    public func handle(input: Input) throws {
        line("<info>Vapor</info> version <comment>\(Application.VERSION)</comment>")
        line("")

        comment("Usage:")
        line("  command [options] [arguments]")
        line("")


        var maxCommandNameLength = 20
        var grouped = [String: [Command]]()

        for command in console.commands {
            let name = command.name
            maxCommandNameLength = max(maxCommandNameLength, name.characters.count + 4)

            let namespace: String

            if let range = name.rangeOfString(":") {
                namespace = name[name.startIndex..<range.startIndex]
            } else {
                namespace = "_"
            }

            if grouped[namespace] == nil {
                grouped[namespace] = []
            }

            grouped[namespace]!.append(command)
        }

        let keys = Array(grouped.keys).sorted()

        for key in keys {
            if key == "_" {
                comment("Available commands:")
            } else {
                comment(" \(key)")
            }

            for command in grouped[key]! {
                let paddedCommand = command.name.pad(with: " ", to: maxCommandNameLength)
                line("  <info>\(paddedCommand)</info>\(command.help ?? "")")
            }
        }
    }

}
