public class Console {
    public init(driver: ConsoleDriver) {
        self.driver = driver
    }

    let driver: ConsoleDriver

    public enum Style {
        case plain
        case info
        case warning
        case error
        case custom(Color)
    }

    public enum Color {
        case black
        case red
        case green
        case yellow
        case blue
        case magenta
        case cyan
        case white
    }

    public func output(_ string: String, style: Console.Style = .info, newLine: Bool = true) {
        driver.output(string, style: style, newLine: newLine)
    }

    public func input() -> String {
        return driver.input()
    }
}
