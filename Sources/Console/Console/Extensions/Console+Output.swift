import COperatingSystem

extension BaseConsole {
    public func blockingWait(seconds: Double) {
        let factor = 1000 * 1000
        let microseconds = seconds * Double(factor)
        usleep(useconds_t(microseconds))
    }
}

// MARK: Style

extension OutputConsole {
    /// Outputs a plain message to the console.
    public func print(_ string: String = "", newLine: Bool = true) {
        output(string, style: .plain, newLine: newLine)
    }

    /// Outputs an informational message to the console.
    public func info(_ string: String = "", newLine: Bool = true) {
        output(string, style: .info, newLine: newLine)
    }

    /// Outputs a success message to the console.
    public func success(_ string: String = "", newLine: Bool = true) {
        output(string, style: .success, newLine: newLine)
    }

    /// Outputs a warning message to the console.
    public func warning(_ string: String = "", newLine: Bool = true) {
        output(string, style: .warning, newLine: newLine)
    }

    /// Outputs an error message to the console.
    public func error(_ string: String = "", newLine: Bool = true) {
        output(string, style: .error, newLine: newLine)
    }
}

