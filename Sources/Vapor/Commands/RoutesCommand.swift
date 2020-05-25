/// Displays all routes registered to the `Application`'s `Router` in an ASCII-formatted table.
///
///     $ swift run Run routes
///     +------+------------------+
///     | GET  | /search          |
///     +------+------------------+
///     | GET  | /hash/:string    |
///     +------+------------------+
///
/// A colon preceding a path component indicates a variable parameter. A colon with no text following
/// is a parameter whose result will be discarded.
///
/// The path will be displayed with the same syntax that is used to register a route.
public final class RoutesCommand: Command {
    public struct Signature: CommandSignature {
        public init() { }
    }

    public var help: String {
        return "Displays all registered routes."
    }

    init() { }

    public func run(using context: CommandContext, signature: Signature) throws {
        let routes = context.application.routes
        let includeDescription = !routes.all.filter { $0.userInfo["description"] != nil }.isEmpty
        let pathSeparator = "/".consoleText()
        context.console.outputASCIITable(routes.all.map { route -> [ConsoleText] in
            let pathText = pathSeparator + route.path.map {
                switch $0 {
                case .constant:
                    return $0.description.consoleText()
                default:
                    return $0.description.consoleText(.info)
                }
            }.joined(separator: pathSeparator)
            var column = [route.method.string.consoleText(), pathText]
            if includeDescription {
                let desc = route.userInfo["description"]
                    .flatMap { $0 as? String }
                    .flatMap { $0.consoleText() } ?? ""
                column.append(desc)
            }
            return column
        })
    }
}

extension Collection where Element == ConsoleText {
    func joined(separator: ConsoleText) -> ConsoleText {
        guard let result: ConsoleText = self.first else {
            return ""
        }
        return self.dropFirst().reduce(into: result) {
            $0 += separator + $1
        }
    }
}

extension Console {
    func outputASCIITable(_ rows: [[ConsoleText]]) {
        var columnWidths: [Int] = []

        // calculate longest columns
        for row in rows {
            for (i, column) in row.enumerated() {
                if columnWidths.count <= i {
                    columnWidths.append(0)
                }
                if column.description.count > columnWidths[i] {
                    columnWidths[i] = column.description.count
                }
            }
        }
        
        func hr() {
            var text: ConsoleText = ""
            for columnWidth in columnWidths {
                text += "+"
                text += "-"
                for _ in 0..<columnWidth {
                    text += "-"
                }
                text += "-"
            }
            text += "+"
            self.output(text)
        }
        
        for row in rows {
            hr()
            var text: ConsoleText = ""
            for (i, column) in row.enumerated() {
                text += "| "
                text += column
                for _ in 0..<(columnWidths[i] - column.description.count) {
                    text += " "
                }
                text += " "
            }
            text += "|"
            self.output(text)
        }
        
        hr()
    }
}
