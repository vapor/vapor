import Console

extension Console {
    /// Runs a command or group of commands on this console using
    /// the supplied arguments.
    public func run(_ runnable: Runnable, arguments: [String]) throws {
        var input = try ParsedInput.parse(from: arguments)
        try run(runnable, with: &input)
    }

    /// Runs a command with the parsed console input.
    private func run(_ runnable: Runnable, with input: inout ParsedInput) throws {
        // try to run subcommand first
        if let group = runnable as? Group {
            if let name = input.arguments.popFirst() {
                guard let chosen = group.commands[name] else {
                    throw CommandError(
                        identifier: "unknownRunnable",
                        reason: "Unknown argument `\(name)`."
                    )
                }
                // executable should include all subcommands
                // to get to the desired command
                input.executable += " " + name
                return try run(chosen, with: &input)
            }
        }

        if input.options["help"] == "true" {
            try outputHelp(for: runnable, executable: input.executable)
        } else {
            let arguments: [Argument]
            if let command = runnable as? Command {
                arguments = command.arguments
            } else {
                arguments = []
            }

            let commandInput = try input.generateInput(
                arguments: arguments,
                options: runnable.options
            )
            try runnable.run(using: self, with: commandInput)
        }
    }
}


