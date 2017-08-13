import libc
import Command
import Console
import Dispatch

extension Droplet {
    enum ExecutionError: Swift.Error {
        case insufficientArguments, noCommandFound
    }

    /// Runs the Droplet's commands, defaulting to serve.
    public func run(arguments: [String] = CommandLine.arguments) throws -> Never  {
        let console = try make(Console.self)
        
        do {
            try runCommands(arguments: arguments)
        } catch CommandError.general(let error) {
            try console.error("Error: ", newLine: false)
            try console.print("\(error)")
            exit(1)
        }
        exit(0)
    }

    func runCommands(arguments: [String]) throws {
        let console = try make(Console.self)
        let commands = try make([Command.self])

        var iterator = arguments.makeIterator()

        guard let executable = iterator.next() else {
            throw CommandError.general("No executable.")
        }

        var args = Array(iterator)

        do {
            // FIXME: figure out how to get the commands and run the console
//            try console.run(
//                executable: executable,
//                commands: commands.map { $0 as Runnable },
//                arguments: args,
//                help: [
//                    "This command line interface is used to serve your droplet, prepare the database, and more.",
//                    "Custom commands can be added by appending them to the Droplet's commands array.",
//                    "Use --help on individual commands to learn more."
//                ]
//            ) 
        } catch {
            throw CommandError.general("\(error)")
        }
    }
}
