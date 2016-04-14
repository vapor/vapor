import VaporConsoleOutput

/// Console class to interact with command line
public class Console {
    private let defaultCommand = "list"
    private var registeredCommands = [String: Command]()

    /// Input instance
    public let input = Input()

    /// Output instance
    public let output = Output()

    /// App instance
    public let app: Application

    /// Get all registered commands
    public var commands: [Command] {
        return Array(registeredCommands.values)
    }

    /// Console errors
    public enum Error: ErrorProtocol {
        case TooManyArguments
        case MissingArgument(argument: String)
        case InvalidOption(option: String)
        case InvalidOptionValue(option: String)
        case MissingOption(option: String)
        case CommandNotFound(command: String)
    }

    /**
        Initialize console
        - parameter application: Application to associate with this instance
        - parameter commands: Optional commands to register with this instance
    */
    public init(application: Application, commands: [Command.Type] = []) {
        self.app = application

        register(ListCommand.self)
        register(ServeCommand.self)

        for command in commands {
            register(command)
        }
    }

    /**
        Run the console
    */
    public func run() {
        app.boot()

        for provider in app.providers {
            if let provider = provider as? ConsoleProvider {
                provider.boot(self)
            }
        }

        let name = input.arguments.first?.value ?? defaultCommand

        do {
            if let command = find(name) {
                var run = command

                if input.hasOption("help") || input.hasOption("h") {
                    run = HelpCommand(command: command, console: self)
                }

                try run.run(input)
            } else {
                throw Error.CommandNotFound(command: name)
            }
        } catch let error as Error {
            output.write("<error>Error: \(error)</error>")
        } catch {
            output.write("<error>Error: \(error)</error>")
        }
    }

    /**
        Register a command
        - parameter command: Command class to initialize and register
    */
    public func register(command: Command.Type) {
        register(command.init(console: self))
    }

    /**
        Register a command
        - parameter command: Command instance to register
    */
    public func register(command: Command) {
        registeredCommands[command.name] = command
    }

    /**
        Unregister a command
        - parameter command: Command name to unregister
    */
    public func unregister(command: String) {
        registeredCommands[command] = nil
    }

    /**
        Check if a command name is registered
        - parameter command: Name of command to check if registered
        - returns: True if register, false if not
    */
    public func contains(command: String) -> Bool {
        return registeredCommands[command] != nil
    }

    /**
        Find a command instance by it’s name
        - parameter command: Name of command to check
        - returns: Command instance if registered, nil if not
    */
    public func find(command: String) -> Command? {
        // swiftlint:disable:next todo
        // TODO: Evaluate implementing alternative suggestions
        return registeredCommands[command]
    }

}
