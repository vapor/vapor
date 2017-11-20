import Console

/// A command that can be run through a console.
public protocol Command: Runnable {
    /// The required arguments.
    var arguments: [Argument] { get }
}

/// A command that can be run through a console.
public protocol Group: Runnable {
    /// A dictionary of runnable commands.
    typealias Commands = [String: Runnable]

    /// This group's subcommands.
    var commands: Commands { get }
}

/// Capable of being run on a console.
/// Note: this base protocol should not be used directly.
/// Conform to Command or Group instead. 
public protocol Runnable {
    /// The supported options.
    var options: [Option] { get }

    /// Text that will be displayed when `--help` is passed.
    var help: [String] { get }

    /// Runs the command against the supplied input.
    func run(using console: Console, with input: Input) throws
}
