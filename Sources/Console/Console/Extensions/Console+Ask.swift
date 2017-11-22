extension InputConsole where Self: OutputConsole {
    /// Requests input from the console
    /// after displaying the desired prompt.
    public func ask(_ prompt: String, style: ConsoleStyle = .info, isSecure: Bool = false) -> String {
        output(prompt, style: style)
        output("> ", style: style, newLine: false)
        return input(isSecure: isSecure)
    }
}
