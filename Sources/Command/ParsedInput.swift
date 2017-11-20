import Console

/// exec foo --baz=bar
internal struct ParsedInput {
    /// exec
    var executable: String

    /// foo
    var arguments: [String]

    /// --baz=bar
    var options: [String: String]

    /// Parses raw array of strings into arguments and options.
    static func parse(from raw: [String]) throws -> ParsedInput {
        guard raw.count > 0 else {
            throw CommandError(
                identifier: "executableRequired",
                reason: "At least one argument is required."
            )
        }
        let executable = raw[0]
        let raw = Array(raw.dropFirst())
        return try ParsedInput(
            executable: executable,
            arguments: self.parseArguments(from: raw),
            options: self.parseOptions(from: raw)
        )
    }

    /// Parses arguments from a raw string array.
    static func parseArguments(from raw: [String]) -> [String] {
        return raw.flatMap { arg in
            guard !arg.hasPrefix("--") else {
                return nil
            }
            return arg
        }
    }

    /// Parses options from a raw string array.
    static func parseOptions(from raw: [String]) throws -> [String: String] {
        var options: [String: String] = [:]

        for arg in raw {
            guard arg.hasPrefix("--") else {
                continue
            }

            let val: String

            let parts = arg.dropFirst(2).split(separator: "=", maxSplits: 1).map(String.init)
            switch parts.count {
            case 1:
                val = "true"
            case 2:
                val = parts[1]
            default:
                throw CommandError(identifier: "invalidOption", reason: "Option \(arg) is incorrectly formatted.")
            }

            options[parts[0]] = val
        }

        return options
    }
}

extension ParsedInput {
    /// Generates Input ready to go to a command against
    /// the supplied arguments and options.
    mutating func generateInput(arguments: [Argument], options: [Option]) throws -> Input {
        var validatedArguments: [String: String] = [:]

        guard arguments.count <= arguments.count else {
            throw CommandError(identifier: "unexpectedArguments", reason: "Too many arguments supplied.")
        }
        for arg in arguments {
            guard let argument = self.arguments.popFirst() else {
                throw CommandError(identifier: "insufficientArguments", reason: "Insufficient arguments supplied.")
            }
            validatedArguments[arg.name] = argument
        }

        var validatedOptions: [String: String] = [:]

        // ensure we don't have any unexpected options
        for key in self.options.keys {
            guard options.contains(where: { $0.name == key }) else {
                throw CommandError(identifier: "unexpectedOptions", reason: "Unexpected option `\(key)`.")
            }
        }

        // set all options to value or default
        for opt in options {
            validatedOptions[opt.name] = self.options[opt.name] ?? opt.default
        }

        return Input(
            executable: executable,
            arguments: validatedArguments,
            options: validatedOptions
        )
    }
}
