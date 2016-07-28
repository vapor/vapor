import libc

extension Droplet {
    enum ExecutionError: Swift.Error {
        case insufficientArguments, noCommandFound
    }

    /**
        Runs the Droplet's commands, defaulting to serve.
    */
    public func serve(_ closure: Serve.ServeFunction? = nil) -> Never  {
        do {
            try runCommands()
        } catch CommandError.general(let error) {
            console.output(error, style: .error)
            exit(1)
        } catch ConsoleError.help {
            exit(0)
        } catch ConsoleError.cancelled {
            exit(2)
        } catch ConsoleError.commandNotFound(let command) {
            console.error("Error: ", newLine: false)
            console.print("Command \"\(command)\" not found.")
            exit(1)
        } catch {
            console.error("Error: ", newLine: false)
            console.print("\(error)")
            exit(1)
        }
    }

    public func runCommands() throws {
        for provider in providers {
            provider.beforeServe(self)
        }

        var iterator = arguments.makeIterator()

        guard let executable = iterator.next() else {
            throw CommandError.general("No executable.")
        }

        var args = Array(iterator)

        if !args.flag("help") && args.values.count == 0 {
            console.warning("No command supplied, defaulting to serve...")
            args.insert("serve", at: 0)
        }

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
    }
}
