//
//  Command.swift
//  Vapor
//
//  Created by Shaun Harrison on 2/20/16.
//

public class Command {
    public let console: Console

    public var app: Application {
        return console.app
    }

    public var name: String {
        fatalError("Subclasses must override the name var")
    }

    public var help: String? {
        return nil
    }

    public var arguments: [InputArgument] {
        return []
    }

    public var options: [InputOption] {
        return []
    }

    internal let defaultOptions = [
        // Triggers HelpCommand
        InputOption("help", mode: .None, help: "Display this help message"),

        // Application reads/applies these values
        InputOption("env", mode: .Optional, help: "Specify an environment to run in."),
        InputOption("workDir", mode: .Optional, help: "Change the work directory.", value: "./")
    ]

    private var compiledArguments = [String: InputArgument]()
    private var compiledOptions = [String: InputOption]()

    public required init(console: Console) {
        self.console = console
    }

    public final func run(input: Input) throws {
        compiledArguments.removeAll()
        compiledOptions.removeAll()

        let arguments = self.arguments
        var options = [String: InputOption]()

        for option in self.options {
            options[option.name] = option
        }

        for option in defaultOptions {
            options[option.name] = option
        }

        // Ensure the input arguments doesn’t exceed the
        // number of defined arguments
        if input.arguments.count - 1 > arguments.count {
            throw Console.Error.TooManyArguments
        }

        // Iterate through input arguments and match them to
        // to the defined arguments
        for (index, argument) in input.arguments.enumerated() {
            if index == 0 {
                continue
            }

            compiledArguments[arguments[index - 1].name] = argument
        }

        // If the input argument count isn’t the same as the
        // defined argument count, iterate through and make sure
        // all the required arguments are satisfied
        if compiledArguments.count != arguments.count {
            for argument in arguments {
                guard argument.mode == .Required else {
                    continue
                }

                if compiledArguments[argument.name] == nil {
                    throw Console.Error.MissingArgument(argument: argument.name)
                }
            }
        }

        // Iterate through input options and match them to
        // the defined options
        for option in input.options {
            guard let definedOption = options[option.name] else {
                throw Console.Error.InvalidOption(option: option.name)
            }

            if definedOption.mode == .None && option.value != nil {
                throw Console.Error.InvalidOptionValue(option: option.name)
            }

            compiledOptions[option.name] = option
        }

        // If the input options count isn’t the same as the
        // defined option count, iterate through and make sure
        // all the required options are satisfied
        if compiledOptions.count != options.count {
            for (_, option) in options {
                guard option.mode != .None && compiledOptions[option.name] == nil else {
                    continue
                }

                if option.mode == .Required {
                    throw Console.Error.MissingOption(option: option.name)
                } else {
                    compiledOptions[option.name] = option
                }
            }
        }

        try handle()
    }

    public func handle() throws {

    }

    public func line(message: String) {
        console.output.writeln(message)
    }

    public func info(message: String) {
        console.output.writeln("<info>\(message)</info>")
    }

    public func comment(message: String) {
        console.output.writeln("<comment>\(message)</comment>")
    }

    public func error(message: String) {
        console.output.writeln("<error>\(message)</error>")
    }

    public func argument(key: String) -> String? {
        return compiledArguments[key]?.value
    }

    public func option(key: String) -> String? {
        return compiledOptions[key]?.value
    }

    public func hasOption(key: String) -> Bool {
        return compiledOptions[key] != nil
    }

}
