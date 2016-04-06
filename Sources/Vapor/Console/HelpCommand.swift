//
//  HelpCommand.swift
//  Vapor
//
//  Created by Shaun Harrison on 2/20/16.
//

internal class HelpCommand: Command {
    private let command: Command

    internal override var options: [InputOption] {
        return [
            InputOption("h", mode: .Optional)
        ]
    }

    internal required init(console: Console) {
        fatalError("HelpCommand should not be invoked this way.")
    }

    internal init(command: Command, console: Console) {
        self.command = command

        super.init(console: console)
    }

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
    internal override func handle() throws {
        let arguments = command.arguments
        let options = command.options + command.defaultOptions

        var usage = "  \(command.name)"

        if options.count > 1 { // All commands have --help
            usage += " [options]"
        }

        if arguments.count > 0 {
            for argument in arguments {
                if argument.mode == .Required {
                    usage += " <\(argument.name)>"
                }
            }
        }

        comment("Usage:")
        line(usage)

        var maxNameLength = 10
        var groups = Dictionary<String, Array<(String, String?, String?)>>()

        if arguments.count > 0 {
            groups["Arguments"] = Array()

            for argument in arguments {
                maxNameLength = max(maxNameLength, argument.name.characters.count + 4)

                groups["Arguments"]!.append((argument.name, argument.help, argument.value))
            }
        }

        if options.count > 0 {
            groups["Options"] = Array()

            for option in options {
                var name = "--\(option.name)"

                if option.mode != .None {
                    name += "[=\(option.name.uppercased())]"
                }

                maxNameLength = max(maxNameLength, name.characters.count + 4)


                groups["Options"]!.append((name, option.help, option.value))
            }
        }

        for (title, infos) in groups {
            line("")
            comment(title + ":")

            for info in infos {
                var line = "<info>\(info.0.pad(with: " ", to: maxNameLength))</info>"

                if let value = info.1 where value.characters.count > 0 {
                    line += value
                }

                if let value = info.2 where value.characters.count > 0 {
                    if info.1?.characters.count > 0 {
                        line += " "
                    }

                    line += "<comment>[default: \"\(value)\"]"
                }

                self.line("  \(line)")
            }
        }

        if let help = command.help {
            line("")
            comment("Help:")
            line("  " + help)
        }
    }
    // swiftlint:enable function_body_length
    // swiftlint:enable cyclomatic_complexity

}
