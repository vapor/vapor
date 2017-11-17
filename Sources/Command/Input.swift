import Console

public struct ConsoleInput {
    public var executable: String
    public var arguments: [String]
    public var options: [String: String]

    public init(raw: [String]) throws {
        guard raw.count > 0 else {
            throw ConsoleError(
                identifier: "executableRequired",
                reason: "At least one argument is required."
            )
        }
        executable = raw[0]

        let raw = Array(raw.dropFirst())
        arguments = ConsoleInput.parseArguments(from: raw)
        options = try ConsoleInput.parseOptions(from: raw)
    }

    public static func parseArguments(from raw: [String]) -> [String] {
        return raw.flatMap { arg in
            guard !arg.hasPrefix("--") else {
                return nil
            }
            return arg
        }
    }

    public static func parseOptions(from raw: [String]) throws -> [String: String] {
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
                throw ConsoleError(identifier: "invalidOption", reason: "Option \(arg) is incorrectly formatted.")
            }

            options[parts[0]] = val
        }

        return options
    }


}

extension ConsoleInput {
    mutating func validate(using signature: CommandSignature) throws -> CommandInput {
        var validatedArguments: [String: String] = [:]

        switch signature.arguments {
        case .array(let arguments):
            guard arguments.count <= arguments.count else {
                throw ConsoleError(identifier: "unexpectedArguments", reason: "Too many arguments supplied.")
            }
            for arg in arguments {
                guard let argument = self.arguments.popFirst() else {
                    throw ConsoleError(identifier: "insufficientArguments", reason: "Insufficient arguments supplied.")
                }
                validatedArguments[arg.name] = argument
            }
        case .group: break
        }

        var validatedOptions: [String: String] = [:]

        // ensure we don't have any unexpected options
        for key in options.keys {
            guard signature.options.contains(where: { $0.name == key }) else {
                throw ConsoleError(identifier: "unexpectedOptions", reason: "Unexpected option `\(key)`.")
            }
        }

        // set all options to value or default
        for opt in signature.options {
            validatedOptions[opt.name] = options[opt.name] ?? opt.default
        }

        return .init(
            executable: executable,
            arguments: validatedArguments,
            options: validatedOptions
        )
    }
}

// MARK: Convenience

extension String {
    public var bool: Bool? {
        switch self {
        case "1", "true", "yes": return true
        case "0", "false", "no": return false
        default: return nil
        }
    }
}
