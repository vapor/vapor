public enum ConsoleAction {
    /// Returns a String of input read from the
    /// console until a line feed character was found.
    ///
    /// The line feed character should not be included.
    ///
    /// If secure is true, the input should not be
    /// shown while it is entered.
    case input(isSecure: Bool)

    /// Outputs a String in the given style to
    /// the console. If newLine is true, the next
    /// output will appear on a new line.
    case output(String, ConsoleStyle, newLine: Bool)

    /// Outputs an error
    case error(String, newLine: Bool)

    /// Clears previously printed Console outputs
    /// according to the clear type given.
    case clear(ConsoleClear)
    
    /// Executes a task using the supplied
    /// FileHandles for IO.
    case execute(
        program: String,
        arguments: [String],
        input: ExecuteStream?,
        output: ExecuteStream?,
        error: ExecuteStream?
    )
}
