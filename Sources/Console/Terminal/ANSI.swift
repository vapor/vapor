import Bits

/// Terminal ANSI commands
enum ANSICommand {
    case eraseScreen
    case eraseLine
    case cursorUp
}

extension Terminal {
    func command(_ command: ANSICommand) throws {
        try action(.output(command.ansi, .plain, newLine: false))
    }
}

extension String {
    /// Wraps a string in the color indicated
    /// by the UInt8 terminal color code.
    func terminalColorize(_ color: ConsoleColor) -> String {
        return color.terminalForeground.ansi + self + Byte(0).ansi
    }
}

// MARK: private

extension ANSICommand {
    /// Converts the command to its ansi code.
    fileprivate var ansi: String {
        switch self {
        case .cursorUp:
            return "1A".ansi
        case .eraseScreen:
            return "2J".ansi
        case .eraseLine:
            return "2K".ansi
        }
    }
}

extension String {
    /// Conversts a String to a full ANSI command.
    fileprivate var ansi: String {
        return "\u{001B}[" + self
    }
}

extension Byte {
    /// Converts a UInt8 to an ANSI code.
    fileprivate var ansi: String {
        return (self.description + "m").ansi
    }
}

extension ConsoleColor {
    /// Returns the foreground terminal color
    /// code for the Color.
    fileprivate var terminalForeground: Byte {
        switch self {
        case .black:
            return 30
        case .red:
            return 31
        case .green:
            return 32
        case .yellow:
            return 33
        case .blue:
            return 34
        case .magenta:
            return 35
        case .cyan:
            return 36
        case .white:
            return 37
        }
    }

    /// Returns the background terminal color
    /// code for the ConsoleColor.
    fileprivate var terminalBackground: Byte {
        switch self {
        case .black:
            return 40
        case .red:
            return 41
        case .green:
            return 42
        case .yellow:
            return 43
        case .blue:
            return 44
        case .magenta:
            return 45
        case .cyan:
            return 46
        case .white:
            return 47
        }
    }
}

