extension Console {
    /// Requests input from the console
    /// after displaying the desired prompt.
    public func ask(_ prompt: String, style: ConsoleStyle = .info, isSecure: Bool = false) throws -> String {
        try output(prompt, style: style)
        try output("> ", style: style, newLine: false)
        return try input(isSecure: isSecure)
    }
}
