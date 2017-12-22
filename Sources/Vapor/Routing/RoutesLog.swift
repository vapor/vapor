import Console
import HTTP
import Foundation

/// A command that can be used to log all routes for 
/// an application. 
///
/// Use from CLI with:
/// vapor run routes
///
/// Use in Xcode with:
/// Droplet(arguments: ["vapor", "routes"])
public final class RouteList: Command {
    public let help: [String] = [
        "Logs the routes of your application"
    ]

    public let id: String = "routes"
    public let console: ConsoleProtocol
    public let router: Router

    /// Initialize a route list command with droplet
    /// requires Droplet reference so that if user updates
    /// console _after_ initializing RouteList
    /// we access latest console.
    public init(_ console: ConsoleProtocol, _ router: Router) {
        self.console = console
        self.router = router
    }

    public func run(arguments: [String] = []) {
        guard arguments.isEmpty else {
            console.kill("invalid arguments \(arguments) expected no arguments")
        }
        let titles = ["Host", "Method", "Path"]
        var table = makeTable(routes: router.routes)
        table.insert(titles, at: 0)
        log(table: table, with: console)
    }

    /// Turns an array of route strings into a list of rows
    func makeTable(routes: [String]) -> [[String]] {
        var hosts: [String: [(method: String, path: String)]] = [:]
        routes.forEach { route in
            let split = route.components(separatedBy: " ")
            guard split.count == 3 else { console.kill("invalid route \(route)") }
            let host = split[0]
            var existing = hosts[host] ?? []

            let method = split[1]
            let path = split[2]
            existing.append((method, path))

            existing.sort { (left, right) in
                left.path < right.path
            }

            hosts[host] = existing
        }

        return hosts.flatMap { host, paths in
            return paths.enumerated().map { idx, pair in
                let path = "/" + pair.path
                guard idx != 0 else { return [host, pair.method, path] }
                return ["", pair.method, path]
            }
        }
    }

    /// Takes a table represented as a list of rows and logs to console
    func log(table rows: [[String]], with console: ConsoleProtocol) {
        // Lint to ensure our table is valid
        guard let numberOfColumns = rows.first?.count else { console.kill("invalid table") }
        rows.forEach { row in
            guard row.count == numberOfColumns else { console.kill("invalid row \(row)") }
        }

        // Get metadata
        let columnWidths = makeColumnWidths(rows: rows)

        // for example: +-----+-------------+
        let separatorLine = separator(columnWidths: columnWidths)

        // top of table
        console.print(separatorLine, newLine: true)

        rows.enumerated().forEach { idx, labels in
            let paddedLabels = labels
                .enumerated().map { idx, label -> String in
                    let length = columnWidths[idx]
                    return label.padded(length: length)
            }

            console.print("| ", newLine: false)
            // title label logs different color than data
            let colorLog = idx == 0 ? console.warning : console.info
            paddedLabels.forEach { label in
                colorLog(label, false)
                console.print(" | ", newLine: false)
            }
            // terminate row
            console.print("", newLine: true)

            // title gets an additional separator
            if idx == 0 {
                console.print(separatorLine, newLine: true)
            }
        }

        // bottom of table
        console.print(separatorLine, newLine: true)
    }

    /// parse various labels to ensure our widths are formatted
    /// to the largest label size
    func makeColumnWidths(rows: [[String]]) -> [Int] {
        var columnWidths = [Int]()
        rows.forEach { labels in
            labels.enumerated().forEach { idx, label in
                while columnWidths.count <= idx { columnWidths.append(0) }
                let length = label.toCharacterSequence().count
                let existing = columnWidths[idx]
                guard length > existing else { return }
                columnWidths[idx] = length
            }
        }
        return columnWidths
    }

    /// Use the given column widths to create a separator
    /// For example: [3, 2] would generate:
    /// +-----+----+
    func separator(columnWidths: [Int]) -> String {
        let separator = columnWidths
            .map { String.dashedLine(length: $0 + 2) }
            .joined(separator: "+")
        return "+" + separator + "+"
    }
}

extension String {
    /// Create a dashed line of given length, ie: 3 => ---
    fileprivate static func dashedLine(length: Int) -> String {
        var line = ""
        while line.toCharacterSequence().count < length {
            line += "-"
        }
        return line
    }

    /// Pad the string with spaces on the end
    fileprivate func padded(length: Int) -> String {
        var new = self
        while new.toCharacterSequence().count < length {
            new += " "
        }
        return new
    }
}

extension ConsoleProtocol {
    fileprivate func kill(_ message: String) -> Never {
        error(message, newLine: true)
        exit(1)
    }
}
