import libc
import Console
import Foundation
import Dispatch

extension Droplet {
    enum ExecutionError: Swift.Error {
        case insufficientArguments, noCommandFound
    }

    /**
        Runs the Droplet's commands, defaulting to serve.
    */
    public func run(servers: [String: ServerConfig]? = nil) -> Never  {
        do {
            try runCommands(servers: servers)
            DispatchQueue.main.sync {
                RunLoop.current.run()
            }
            exit(0)
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

    func runCommands(servers: [String: ServerConfig]? = nil) throws {
        // the prepare command will run all
        // of the supplied preparations on the database.
        let prepare = Prepare(console: console, preparations: self.preparations, database: self.database)

        // the serve command will boot the servers
        // and always runs the prepare command
        let serve = Serve(console: console, prepare: prepare) {
            try self.bootServers(servers)
        }

        // the version command prints the frameworks version.
        let version = VersionCommand(console: console)

        // adds the commands
        commands.append(serve)
        commands.append(prepare)
        commands.append(version)
        
        for provider in providers {
            provider.beforeRun(self)
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
