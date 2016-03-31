//
//  Console.swift
//  Vapor
//
//  Created by Shaun Harrison on 2/20/16.
//

import VaporConsoleOutput

public class Console {
    private let defaultCommand = "list"
    private var commands = [String: Command]()

    public let input = Input()
    public let output = Output()
    public let app: Application

    public enum Error: ErrorProtocol {
        case TooManyArguments
        case MissingArgument(argument: String)
        case InvalidOption(option: String)
        case InvalidOptionValue(option: String)
        case MissingOption(option: String)
        case CommandNotFound(command: String)
    }

    public init(application: Application, commands: [Command.Type] = []) {
        self.app = application

        register(ListCommand.self)
        register(ServeCommand.self)

        for command in commands {
            register(command)
        }
    }

    public func run() {
        app.boot()

        for provider in app.providers {
            if let provider = provider as? ConsoleProvider.Type {
                provider.boot(self)
            }
        }

        let name = input.arguments.first?.value ?? defaultCommand

        do {
            if let command = find(name) {
                var run = command

                if input.hasParameterOption("help") || input.hasParameterOption("h") {
                    run = HelpCommand(command: command, console: self)
                }

                try run.run(input)
            } else {
                throw Error.CommandNotFound(command: name)
            }
        } catch let error as Error {
            output.writeln("<error>Error: \(error)</error>");
        } catch {
            output.writeln("<error>Error: \(error)</error>");
        }
    }

    public func register(command: Command.Type) {
        register(command.init(console: self))
    }

    public func register(command: Command) {
        commands[command.name] = command
    }

    public func unregister(command: String) {
        commands[command] = nil
    }

    public func contains(command: String) -> Bool {
        return commands[command] != nil
    }

    public func find(command: String) -> Command? {
        // TODO: Implement alternative suggestions
        return commands[command]
    }

    public func allCommands() -> [Command] {
        return Array(commands.values)
    }

}
