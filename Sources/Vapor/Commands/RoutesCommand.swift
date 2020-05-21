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
/// An asterisk indicates a catch-all. Any path components after a catch-all will be discarded and ignored.
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
        context.console.outputASCIITable(routes.all.map { route -> [ConsoleText] in
            var pathText: ConsoleText = ""
            if route.path.isEmpty {
                pathText += "/".consoleText(.info)
            }
            for path in route.path {
                pathText += "/".consoleText(.info)
                switch path {
                case .constant(let string):
                    if string != "/" {
                        pathText += string.consoleText()
                    }
                case .parameter(let name):
                    pathText += ":".consoleText(.info)
                    pathText += name.consoleText()
                case .anything:
                    pathText += ":".consoleText(.info)
                case .catchall:
                    pathText += "*".consoleText(.info)
                }
            }
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
