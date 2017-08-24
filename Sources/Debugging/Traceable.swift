public protocol Traceable {
    var file: String { get }
    var function: String { get }
    var line: UInt { get }
    var column: UInt { get }
    var stackTrace: [String] { get }
    var range: Range<UInt>? { get }
}

extension Traceable {
    public func traceableHelp(format: HelpFormat) -> String {

        switch format {
        case .long:
            var help: [String] = []
            help.append("File: \(file)")
            help.append(" - func: \(function)")
            help.append(" - line: \(line)")
            help.append(" - column: \(column)")
            if let range = range {
                help.append("- range: \(range)")
            }
            return help.joined(separator: "\n")
        case .short:
            var string = "[\(file):\(line):\(column)"
            if let range = range {
                string += " (\(range))"
            }
            string += "]"
            return string
        }

    }
}

extension Traceable {
    public static func makeStackTrace() -> [String] {
        return StackTrace.get()
    }
}

extension Traceable {
    public var range: Range<UInt>? {
        return nil
    }
}


public enum HelpFormat {
    case short
    case long
}
