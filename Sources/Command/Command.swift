import Console

/// A command that can be run through a console.
public protocol Command {
    /// This command's support arguments and options.
    /// See CommandSignature.
    var signature: CommandSignature { get }

    /// Runs the command against the supplied input.
    func run(using console: Console, with input: CommandInput) throws
}
