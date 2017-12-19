import Service

/// Protocol for powering styled Console I/O.
public protocol BaseConsole: Extendable {
    /// The size of the console window used for
    /// calculating lines printed and centering tet.
    var size: (width: Int, height: Int) { get }
}

// MARK: Input

public protocol InputConsole: BaseConsole {
    /// Returns a String of input read from the
    /// console until a line feed character was found.
    ///
    /// The line feed character should not be included.
    ///
    /// If secure is true, the input should not be
    /// shown while it is entered.
    func input(isSecure: Bool) -> String
}

extension InputConsole {
    /// See InputConsole.input
    /// note: Defaults to non secure input.
    public func input() -> String {
        return input(isSecure: false)
    }
}

// MARK: Output

/// A console capable of outputting styled strings.
public protocol OutputConsole: BaseConsole {
    /// Outputs a String in the given style to
    /// the console. If newLine is true, the next
    /// output will appear on a new line.
    func output(_ string: String, style: ConsoleStyle, newLine: Bool)
}

extension OutputConsole {
    /// See OutputConsole.output
    public func output(_ string: String, style: ConsoleStyle) {
        self.output(string, style: style, newLine: true)
    }
}

/// A console capable of outputting errors.
public protocol ErrorConsole: BaseConsole {
    /// Outputs an error
    func report(error: String, newLine: Bool)
}

public protocol ClearableConsole: BaseConsole {
    /// Clears previously printed Console outputs
    /// according to the clear type given.
    func clear(_ type: ConsoleClear)
}

// MARK: Execute

public protocol ExecuteConsole: BaseConsole {
    /// Executes a task using the supplied
    /// FileHandles for IO.
    func execute(
        program: String,
        arguments: [String],
        input: ExecuteStream?,
        output: ExecuteStream?,
        error: ExecuteStream?
    ) throws
}

// MARK: All

public protocol Console: InputConsole, OutputConsole, ErrorConsole, ClearableConsole, ExecuteConsole { }
