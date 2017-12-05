extension ClearableConsole {
//    /// Performs the supplied clear type.
//    public func clear(_ clear: ConsoleClear) throws {
//        didOutputLines(count: -1)
//        try action(.clear(clear))
//    }

    /// Clears n lines from the terminal.
    public func clear(lines: Int) throws {
        for _ in 0..<lines {
            clear(.line)
        }
    }
}

