import Command
import Console
import HTTP
import Foundation
import Service

/// A command that can be used to log all routes for 
/// an application. 
///
/// Use from CLI with:
/// vapor run routes
///
/// Use in Xcode with:
/// Droplet(arguments: ["vapor", "routes"])
public final class RouteList: Command {
    public let signature: CommandSignature
    public let console: Console
    public let router: RouterProtocol

    /// Initialize a route list command with droplet
    /// requires Droplet reference so that if user updates
    /// console _after_ initializing RouteList
    /// we access latest console.
    public init(console: Console, router: RouterProtocol) {
        self.signature = .init(arguments: [], options: [], help: ["Logs the routes of your application"])
        self.console = console
        self.router = router
    }

    public func run(using console: Console, with input: CommandInput) throws {
        let titles = ["Host", "Method", "Path"]
        var table = try makeTable(routes: router.routes)
        table.insert(titles, at: 0)
        try log(table: table, with: console)
    }

    /// Turns an array of route strings into a list of rows
    func makeTable(routes: [String]) throws -> [[String]] {
        var hosts: [String: [(method: String, path: String)]] = [:]
        try routes.forEach { route in
            let split = route.components(separatedBy: " ")
            guard split.count == 3 else { try console.kill("invalid route \(route)") }
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
    func log(table rows: [[String]], with console: Console) throws {
        // Lint to ensure our table is valid
        guard let numberOfColumns = rows.first?.count else {
            try console.kill("invalid table")
        }
        try rows.forEach { row in
            guard row.count == numberOfColumns else {
                try console.kill("invalid row \(row)")
            }
        }

        // Get metadata
        let columnWidths = makeColumnWidths(rows: rows)

        // for example: +-----+-------------+
        let separatorLine = separator(columnWidths: columnWidths)

        // top of table
        try console.print(separatorLine, newLine: true)

        try rows.enumerated().forEach { idx, labels in
            let paddedLabels = labels
                .enumerated().map { idx, label -> String in
                    let length = columnWidths[idx]
                    return label.padded(length: length)
            }

            try console.print("| ", newLine: false)
            // title label logs different color than data
            let colorLog = idx == 0 ? console.warning : console.info
            try paddedLabels.forEach { label in
                try colorLog(label, false)
                try console.print(" | ", newLine: false)
            }
            // terminate row
            try console.print("", newLine: true)

            // title gets an additional separator
            if idx == 0 {
                try console.print(separatorLine, newLine: true)
            }
        }

        // bottom of table
        try console.print(separatorLine, newLine: true)
    }

    /// parse various labels to ensure our widths are formatted
    /// to the largest label size
    func makeColumnWidths(rows: [[String]]) -> [Int] {
        var columnWidths = [Int]()
        rows.forEach { labels in
            labels.enumerated().forEach { idx, label in
                while columnWidths.count <= idx { columnWidths.append(0) }
                let length = label.characters.count
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
        while line.characters.count < length {
            line += "-"
        }
        return line
    }

    /// Pad the string with spaces on the end
    fileprivate func padded(length: Int) -> String {
        var new = self
        while new.characters.count < length {
            new += " "
        }
        return new
    }
}

extension Console {
    fileprivate func kill(_ message: String) throws -> Never {
        try error(message, newLine: true)
        exit(1)
    }
}

extension RouteList: ServiceType {
    /// See Service.name
    public static var serviceName: String {
        return "routes"
    }

    /// See Service.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [Command.self]
    }

    /// See Service.make
    public static func makeService(for container: Container) throws -> Self? {
        return try .init(
            console: container.make(),
            router: container.make()
        )
    }
}
