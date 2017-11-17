import Console

extension Console {
    /// Outputs help for a command.
    public func outputHelp(for command: Command, executable: String) throws {
        try info("Usage: ", newLine: false)
        try print(executable + " ", newLine: false)

        switch command.signature.arguments {
        case .array(let arguments):
            for arg in arguments {
                try warning("<" + arg.name + "> ", newLine: false)
            }
        case .group:
            try warning("<command> ", newLine: false)
        }
        for opt in command.signature.options {
            try success("[--" + opt.name + "] ", newLine: false)
        }
        try print()

        try print()

        for help in command.signature.help {
            try print(help)
        }

        let padding: Int

        switch command.signature.arguments {
        case .array(let arguments):
            padding = (arguments.map { $0.name }
                + command.signature.options.map { $0.name })
                .longestCount + 2
        case .group(let runnables):
            padding = (runnables.keys
                + command.signature.options.map { $0.name })
                .longestCount + 2
        }


        try print()
        switch command.signature.arguments {
        case .array(let arguments):
            if arguments.count > 0 {
                try info("Arguments:")
                for arg in arguments {
                    try outputHelpListItem(name: arg.name, help: arg.help, style: .warning, padding: padding)
                }
            }
        case .group(let runnables):
            if runnables.count > 0 {
                try success("Commands:")
                for (key, runnable) in runnables {
                    try outputHelpListItem(name: key, help: runnable.signature.help, style: .warning, padding: padding)
                }
            }
        }

        try print()
        if command.signature.options.count > 0 {
            try success("Options:")
            for opt in command.signature.options {
                try outputHelpListItem(name: opt.name, help: opt.help, style: .success, padding: padding)
            }
        }

        try print()

        switch command.signature.arguments {
        case .group:
            try print()
            try print("Use `\(executable) ", newLine: false)
            try warning("command", newLine: false)
            try print(" --help` for more information on a command.")
        case .array: break
        }
    }

    private func outputHelpListItem(name: String, help: [String], style: ConsoleStyle, padding: Int) throws {
        try output(name.leftPad(to: padding - name.count), style: style, newLine: false)
        for (i, help) in help.enumerated() {
            if i == 0 {
                try print(help.leftPad(to: 1))
            } else {
                try print(help.leftPad(to: padding + 1))
            }
        }
    }
}

extension String {
    fileprivate func leftPad(to padding: Int) -> String {
        return String(repeating: " ", count: padding) + self
    }
}

extension Array where Element == String {
    fileprivate var longestCount: Int {
        var count = 0

        for item in self {
            if item.count > count {
                count = item.count
            }
        }

        return count
    }
}
