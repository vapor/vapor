public class Terminal: ConsoleDriver {
    let startOfCode = "\u{001B}["
    let endOfCode = "m"

    public init() {

    }

    public func output(_ string: String, style: Console.Style, newLine: Bool) {
        let terminator = newLine ? "\n" : ""

        let color: Console.Color?
        switch style {
        case .plain:
            color = nil
        case .info:
            color = .cyan
        case .warning:
            color = .yellow
        case .error:
            color = .red
        case .success:
            color = .green
        case .custom(let c):
            color = c
        }

        let output: String
        if let color = color {
            output = "\(startOfCode)\(color.terminal)\(endOfCode)" + string + "\(startOfCode)\(0)\(endOfCode)"
        } else {
            output = string
        }

        Swift.print(output, terminator: terminator)
    }

    public func input() -> String {
        return readLine(strippingNewline: true) ?? ""
    }
}

extension Console.Color {
    var terminal: Int {
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
}
