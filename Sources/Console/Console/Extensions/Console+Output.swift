import libc

extension Console {
    /// Output method with plain default and newline.
    public func output(_ string: String, style: ConsoleStyle = .plain, newLine: Bool = true) throws {
        var lines = 0
        let count = string.count
        if count > size.width && count > 0 && size.width > 0 {
            lines += (count / size.width) + 1
        }
        if newLine {
            lines += 1
        }
        didOutputLines(count: lines)
        try action(.output(string, style, newLine: newLine))
    }

    public func wait(seconds: Double) {
        let factor = 1000 * 1000
        let microseconds = seconds * Double(factor)
        usleep(useconds_t(microseconds))
    }
}

// MARK: Style

extension Console {
    /// Outputs a plain message to the console.
    public func print(_ string: String = "", newLine: Bool = true) throws {
        try output(string, style: .plain, newLine: newLine)
    }

    /// Outputs an informational message to the console.
    public func info(_ string: String = "", newLine: Bool = true) throws {
        try output(string, style: .info, newLine: newLine)
    }

    /// Outputs a success message to the console.
    public func success(_ string: String = "", newLine: Bool = true) throws {
        try output(string, style: .success, newLine: newLine)
    }

    /// Outputs a warning message to the console.
    public func warning(_ string: String = "", newLine: Bool = true) throws {
        try output(string, style: .warning, newLine: newLine)
    }

    /// Outputs an error message to the console.
    public func error(_ string: String = "", newLine: Bool = true) throws {
        try output(string, style: .error, newLine: newLine)
    }
}

