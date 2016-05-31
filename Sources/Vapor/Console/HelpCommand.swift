//internal class HelpCommand: Command {
//    private typealias OutputGroup = [(String, String?, String?)]
//
//    private let command: Command
//    private var maxNameLength = 10
//
//    internal let console: Console
//    internal let name = "help"
//    internal let options = [ InputOption("h", mode: .Optional) ]
//
//    internal required init(console: Console) {
//        fatalError("HelpCommand should not be invoked this way.")
//    }
//
//    internal init(command: Command, console: Console) {
//        self.command = command
//        self.console = console
//    }
//
//    internal func handle(input: Input) throws {
//        let arguments = command.arguments
//        let options = command.options + command.defaultOptions
//
//        var usage = "  \(command.name)"
//
//        if options.count > 1 { // All commands have --help
//            usage += " [options]"
//        }
//
//        if arguments.count > 0 {
//            for argument in arguments {
//                if argument.mode == .Required {
//                    usage += " <\(argument.name)>"
//                }
//            }
//        }
//
//        comment("Usage:")
//        line(usage)
//
//        var groups = [String: OutputGroup]()
//        self.build(arguments: arguments, to: &groups)
//        self.build(options: options, to: &groups)
//        self.writeGroups(groups)
//
//        if let help = command.help {
//            line("")
//            comment("Help:")
//            line("  " + help)
//        }
//    }
//
//    private func build(arguments args: [InputArgument], to groups: inout [String: OutputGroup]) {
//        guard args.count > 0  else {
//            return
//        }
//
//        var group = OutputGroup()
//
//        for argument in args {
//            maxNameLength = max(maxNameLength, argument.name.characters.count + 4)
//            group.append((argument.name, argument.help, argument.value))
//        }
//
//        groups["Arguments"] = group
//    }
//
//    private func build(options options: [InputOption], to groups: inout [String: OutputGroup]) {
//        guard options.count > 0  else {
//            return
//        }
//
//        var group = OutputGroup()
//
//        for option in options {
//            var name = "--\(option.name)"
//
//            if option.mode != .None {
//                name += "[=\(option.name.uppercased())]"
//            }
//
//            maxNameLength = max(maxNameLength, name.characters.count + 4)
//            group.append((name, option.help, option.value))
//        }
//
//        groups["Options"] = group
//    }
//
//    private func writeGroups(groups: [String: OutputGroup]) {
//        for (title, group) in groups {
//            line("")
//            comment(title + ":")
//
//            for info in group {
//                var line = "<info>\(info.0.pad(with: " ", to: maxNameLength))</info>"
//
//                if let value = info.1 where value.characters.count > 0 {
//                    line += value
//                }
//
//                if let value = info.2 where value.characters.count > 0 {
//                    if info.1?.characters.count > 0 {
//                        line += " "
//                    }
//
//                    line += "<comment>[default: \"\(value)\"]"
//                }
//
//                self.line("  \(line)")
//            }
//        }
//    }
//
//}
