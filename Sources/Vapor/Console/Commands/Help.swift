public struct Help: Command {
    public static let id = "help"
    public static func run(on app: Application, with subcommands: [String]) {
        var output = "Available Commands: \n"
        output += app.commands
            .values
            .filter { $0.id != "\(id)" }
            .helpOutput()
        output += "\n"
        print(output)
    }
}

extension Command {
    private static func helpOutput() -> String {
        var output = "\t\(id)\n"
        help.forEach { line in
            output += "\t\t\(line)\n"
        }
        return output
    }
}

extension Sequence where Iterator.Element == Command.Type {
    private func helpOutput() -> String {
        var output = ""
        forEach { cmd in
            output += cmd.helpOutput()
        }
        return output
    }
}
