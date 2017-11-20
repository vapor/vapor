import Console

/// Parsed input to a command.
public struct Input {
    /// The name of the executable.
    public let executable: String

    /// All arguments stored by name.
    /// note: use `argument` method instead.
    internal let arguments: [String: String]

    /// All options stored by name.
    public let options: [String: String]

    /// Retrieve the argument with the given name or throws an error.
    public func argument(_ name: String) throws -> String {
        guard let arg = arguments[name] else {
            throw CommandError(
                identifier: "missingArgument",
                reason: "No argument named `\(name)` exists in the command signature."
            )
        }

        return arg
    }

    /// Retrieves the option with the supplied name or throws an error.
    public func requireOption(_ name: String) throws -> String {
        guard let option = options[name] else {
            throw CommandError(
                identifier: "missingOption",
                reason: "Option `\(name)` is required and was not supplied."
            )
        }

        return option
    }
}
