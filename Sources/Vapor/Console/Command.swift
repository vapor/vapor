//
//  Command.swift
//  Vapor
//
//  Created by Shaun Harrison on 2/20/16.
//

/** Console command base class */
public class Command {
    ///Console this command is registered to
    public let console: Console

    ///Convenience accessor for the console’s app
    public var app: Application {
        return console.app
    }

    ///Name of the command (Subclasses must override)
    public var name: String {
        fatalError("Subclasses must override the name var")
    }

    ///Optional help info for the command
    public var help: String? {
        return nil
    }

    ///Arguments for this command (Subclasses should override to populate)
    public var arguments: [InputArgument] {
        return []
    }

    ///Options for this command (Subclasses should override to populate)
    public var options: [InputOption] {
        return []
    }

    ///Default options every command has
    internal let defaultOptions = [
        // Triggers HelpCommand
        InputOption("help", mode: .None, help: "Display this help message"),

        // Application reads/applies these values
        InputOption("env", mode: .Optional, help: "Specify an environment to run in."),
        InputOption("workDir", mode: .Optional, help: "Change the work directory.", value: "./")
    ]

    private var compiledArguments = [String: InputArgument]()
    private var compiledOptions = [String: InputOption]()

    /**
        Initialize the command
        - parameter console: Console instance this command will be registered on
    */
    public required init(console: Console) {
        self.console = console
    }

    // swiftlint:disable cyclomatic_complexity
    /**
        Run the command
        - parameter input: Instance of input to provide arguments/options for this command
        - throws: Console.Error
    */
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
    // swiftlint:enable cyclomatic_complexity

    /**
        Called by `run()` for subclasses to override
        and implement their command logic
        - throws: Console.Error
    */
    public func handle() throws {

    }

    /**
        Write a message without any formatting
        - parameter message: Message to write
    */
    public func line(message: String) {
        console.output.writeln(message)
    }

    /**
        Write an info message
        - parameter message: Info message to write
    */
    public func info(message: String) {
        console.output.writeln("<info>\(message)</info>")
    }

    /**
        Write a comment message
        - parameter message: Comment message to write
    */
    public func comment(message: String) {
        console.output.writeln("<comment>\(message)</comment>")
    }

    /**
        Write an error message
        - parameter message: Error message to write
    */
    public func error(message: String) {
        console.output.writeln("<error>\(message)</error>")
    }

    /**
        Get an argument value
        - parameter name: Name of argument to get value for
        - returns: Argument value, if present
    */
    public func argument(name: String) -> String? {
        return compiledArguments[name]?.value
    }

    /**
        Get an option value
        - parameter name: Name of option to get value for
        - returns: Option value, if present
    */
    public func option(name: String) -> String? {
        return compiledOptions[name]?.value
    }

    /**
        Check if an option is present
        This is useful for flag options with no value
        - parameter name: Name of option to check for
        - returns: True if option is present, false if not
    */
    public func hasOption(name: String) -> Bool {
        return compiledOptions[name] != nil
    }

}
