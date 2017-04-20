import libc
import Console
import Dispatch

extension Droplet {
    enum ExecutionError: Swift.Error {
        case insufficientArguments, noCommandFound
    }

    /// Runs the Droplet's commands, defaulting to serve.
    public func run() throws -> Never  {
        do {
            try runCommands()
        } catch CommandError.general(let error) {
            console.error("Error: ", newLine: false)
            console.print("\(error)")
            exit(1)
        }
        exit(0)
    }

    func runCommands() throws {
        for provider in config.providers {
            try provider.beforeRun(self)
        }

        var iterator = config.arguments.makeIterator()

        guard let executable = iterator.next() else {
            throw CommandError.general("No executable.")
        }

        var args = Array(iterator)

        if !args.flag("help") && args.values.count == 0 {
            console.warning("No command supplied, defaulting to serve...")
            args.insert("serve", at: 0)
        }

        do {
            try console.run(
                executable: executable,
                commands: commands.map { $0 as Runnable },
                arguments: args,
                help: [
                    "This command line interface is used to serve your droplet, prepare the database, and more.",
                    "Custom commands can be added by appending them to the Droplet's commands array.",
                    "Use --help on individual commands to learn more."
                ]
            )
        } catch ConsoleError.help {
            // nothing
        } catch {
            throw CommandError.general("\(error)")
        }
    }
}
