/**
    Objects capable of sending output to
    and receiving input from a console can
    conform to this protocol to power the Console.
*/
public protocol Console {
    func output(_ string: String, style: ConsoleStyle, newLine: Bool)
    func input() -> String
}

public enum ConsoleStyle {
    case plain
    case info
    case warning
    case error
    case success
    case custom(ConsoleColor)
}

public enum ConsoleColor {
    case black
    case red
    case green
    case yellow
    case blue
    case magenta
    case cyan
    case white
}

extension Console {
    public func output(_ string: String, style: ConsoleStyle = .plain, newLine: Bool = true) {
        output(string, style: style, newLine: newLine)
    }
}
