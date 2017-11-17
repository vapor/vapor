import Console

extension Console {
    /// Runs a command or group of commands on this console using
    /// the supplied arguments.
    public func run(_ command: Command, arguments: [String]) throws {
        var input = try ConsoleInput(raw: arguments)
        try run(command, with: &input)
    }

    /// Runs a command with the parsed console input.
    private func run(_ command: Command, with input: inout ConsoleInput) throws {
        switch command.signature.arguments {
        case .array:
            if input.options["help"]?.bool == true {
                try outputHelp(for: command, executable: input.executable)
            } else {
                let validated = try input.validate(using: command.signature)
                try command.run(using: self, with: validated)
            }
        case .group(let runnables):
            if let name = input.arguments.popFirst() {
                guard let chosen = runnables[name] else {
                    throw ConsoleError(
                        identifier: "unknownRunnable",
                        reason: "Unknown argument `\(name)`."
                    )
                }
                // executable should include all subcommands
                // to get to the desired command
                input.executable += " " + name
                try run(chosen, with: &input)
            } else {
                if input.options["help"]?.bool == true {
                    try outputHelp(for: command, executable: input.executable)
                } else {
                    let validated = try input.validate(using: command.signature)
                    try command.run(using: self, with: validated)
                }
            }
        }
    }
}


