//import Console
//import Command
//
///// Vapor's main command.
//internal struct MainCommand: CommandGroup {
//    var commands: [String: CommandRunnable]
//    var defaultRunnable: CommandRunnable?
//    var options: [CommandOption]
//    var help: [String]
//
//    init(commands: [String: CommandRunnable], defaultRunnable: CommandRunnable?) {
//        self.commands = commands
//        self.options = [
//            .flag(name: "version", short: "v", help: ["Displays the framework's version"])
//        ]
//        self.help = ["Runs your Vapor application's commands"]
//        self.defaultRunnable = defaultRunnable
//    }
//
//    func run(using context: CommandContext) throws -> Future<Void> {
//        if context.options["version"] == "true" {
//            context.console.info("Vapor Framework v", newLine: false)
//            context.console.print("3.0")
//        } else {
//            if let lazy = self.defaultRunnable {
//                return try lazy.run(using: context)
//            } else {
//                throw VaporError(identifier: "noDefaultCommand", reason: "No default command has been registered.", source: .capture())
//            }
//        }
//        return .done(on: context.container)
//    }
//}
