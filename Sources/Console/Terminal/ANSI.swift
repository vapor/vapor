import Bits

/// Terminal ANSI commands
enum ANSICommand {
    case eraseScreen
    case eraseLine
    case cursorUp
    case sgrReset
}

extension Terminal {
    func command(_ command: ANSICommand) {
        Swift.print(command.ansi, terminator: "")
    }
}

extension String {
    /// Wraps a string in the color indicated
    /// by the UInt8 terminal color code.
    func terminalColorize(_ color: ConsoleColor, background bgcolor: ConsoleColor? = nil) -> String {
        return
            (color.terminalForeground + (bgcolor.map { ";" + $0.terminalBackground } ?? "")).sgr +
            self +
            ANSICommand.sgrReset.ansi
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
        case .sgrReset:
            return "0".sgr
        }
    }
}

extension String {
    /// Conversts a String to a full ANSI command.
    fileprivate var ansi: String {
        return "\u{001B}[" + self
    }
    /// Converts a String to a full ANSI
    /// "Set Graphic Rendition" command.
    fileprivate var sgr: String {
        return (self + "m").ansi
    }
}

extension ConsoleColor {
    /// Returns the foreground terminal color
    /// code for the Color.
    fileprivate var terminalForeground: String {
        return (self.isBold ? "1;" : "0;") + ((self.isBright ? 90 : 30) + self.underlyingColorCode).description
    }
    
    /// Returns the background terminal color
    /// code for the ConsoleColor.
    /// - Note: Boldness is ignored for background
    /// colors, as there is no intuitive corresponding
    /// concept (underline or blink could be used, but
    /// then the color is no longer doing what it says)
    fileprivate var terminalBackground: String {
        return ((self.isBright ? 100 : 40) + self.underlyingColorCode).description
    }
    
    /// Returns the "color offset" code for the
    /// `ConsoleColor`
    /// - Note: This value is technically a 3-bit
    /// bitmask - magenta(5) is red(1)+blue(4), cyan(6) is
    /// green(2)+blue(4), white is red(1)+green(2)+blue(4),
    /// etc.
    fileprivate var underlyingColorCode: Int {
        switch self {
        case .black, .brightBlack, .boldBlack, .boldBrightBlack:
            return 0
        case .red, .brightRed, .boldRed, .boldBrightRed:
            return 1
        case .green, .brightGreen, .boldGreen, .boldBrightGreen:
            return 2
        case .yellow, .brightYellow, .boldYellow, .boldBrightYellow:
            return 3
        case .blue, .brightBlue, .boldBlue, .boldBrightBlue:
            return 4
        case .magenta, .brightMagenta, .boldMagenta, .boldBrightMagenta:
            return 5
        case .cyan, .brightCyan, .boldCyan, .boldBrightCyan:
            return 6
        case .white, .brightWhite, .boldWhite, .boldBrightWhite:
            return 7
        }
    }
    
    /// Whether the color is "bright" - not the same as bold!
    fileprivate var isBright: Bool {
        switch self {
        case .brightBlack, .boldBrightBlack,
             .brightRed, .boldBrightRed,
             .brightGreen, .boldBrightGreen,
             .brightYellow, .boldBrightYellow,
             .brightBlue, .boldBrightBlue,
             .brightMagenta, .boldBrightMagenta,
             .brightCyan, .boldBrightCyan,
             .brightWhite, .boldBrightWhite:
            return true
        default:
            return false
        }
    }

    /// Whether the color is "bold" - not the same as bright!
    fileprivate var isBold: Bool {
        switch self {
        case .boldBlack, .boldBrightBlack,
             .boldRed, .boldBrightRed,
             .boldGreen, .boldBrightGreen,
             .boldYellow, .boldBrightYellow,
             .boldBlue, .boldBrightBlue,
             .boldMagenta, .boldBrightMagenta,
             .boldCyan, .boldBrightCyan,
             .boldWhite, .boldBrightWhite:
            return true
        default:
            return false
        }
    }
}

