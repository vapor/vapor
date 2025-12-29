import RoutingKit
import HTTPTypes

extension Application {
    /// Returns all routes registered to the `Application`'s `Router` in an ASCII-formatted table `String`.
    ///
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
    public func routesASCIITable() -> String {
        let routes = self.routes
        let includeDescription = !routes.all.filter { $0.userInfo["description"] != nil }.isEmpty
        let pathSeparator = "/"
        return String.asciiTable(routes.all.map { route -> [String] in
            var column = [route.method.rawValue]
            if route.path.isEmpty {
                column.append(pathSeparator)
            } else {
                column.append(route.path
                    .map { pathSeparator + $0.description }
                    .reduce("", +)
                )
            }
            if includeDescription {
                let desc = route.userInfo["description"]
                    .flatMap { $0 as? String }
                    .flatMap { $0 } ?? ""
                column.append(desc)
            }
            return column
        })
    }
}

extension String {
    static fileprivate func asciiTable(_ rows: [[String]]) -> String {
        var output = ""
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
            var text = ""
            for columnWidth in columnWidths {
                text += "+"
                text += "-"
                for _ in 0..<columnWidth {
                    text += "-"
                }
                text += "-"
            }
            text += "+"
            output += text + "\n"
        }

        for row in rows {
            hr()
            var text = ""
            for (i, column) in row.enumerated() {
                text += "| "
                text += column
                for _ in 0..<(columnWidths[i] - column.count) {
                    text += " "
                }
                text += " "
            }
            text += "|"
            output += text + "\n"
        }

        hr()
        return output
    }
}
