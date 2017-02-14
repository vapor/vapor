
// FIXME: import Vapor

import Fluent

extension Droplet {
    fileprivate var preparations: [Preparation.Type] {
        get {
            guard let existing = storage["fluent-preparations"] as? [Preparation.Type] else { return [] }
            return existing
        }
        set {
            storage["fluent-preparations"] = newValue
        }
    }
}

fileprivate final class FluentVaporProvider: Provider {

    let servers: [String: ServerConfig]?
    fileprivate init(config: Settings.Config) throws {
        print("Ignoring config: \(config)")
        servers = nil
    }

    fileprivate init(servers: [String: ServerConfig]) {
        self.servers = servers
    }

    /**
     Called before the Droplet begins serving
     which is @noreturn.
     */
    fileprivate func beforeRun(_ drop: Droplet) {
        // the prepare command will run all
        // of the supplied preparations on the database.
        // FIXME: This should really happen later in cycle if possible, so maybe Providers need some sort of order preference
        let prepare = Prepare(console: drop.console, preparations: drop.preparations, database: drop.database)
        drop.commands.append(prepare)

        let fluentServe = FluentVaporServe(console: drop.console, prepare: prepare) {
            // nonblocking
            // let servers = self.servers ?? drop.parseServersConfig()
            // try self.startServers(servers)()

            // blocking
            let servers = self.servers ?? drop.parseServersConfig()
            try drop.bootServers(servers)
        }

        // remove standard serve
        drop.commands = drop.commands.filter { $0.id != "serve" }
        // add in new serve
        drop.commands.append(fluentServe)

    }

    fileprivate func boot(_ drop: Droplet) {
        drop.preparations.forEach { preparation in }
    }
}

import Console
import HTTP

/**
 Serves the droplet.
 */
public class FluentVaporServe: Command {
    public typealias ServeFunction = () throws -> ()

    public let signature: [Argument] = [
        Option(name: "port", help: ["Overrides the default serving port."]),
        Option(name: "workdir", help: ["Overrides the working directory to a custom path."])
    ]

    public let help: [String] = [
        "Boots the Droplet's servers and begins accepting requests."
    ]

    public let id: String = "serve"
    public let serve: ServeFunction
    public let console: ConsoleProtocol
    public let prepare: Prepare

    public required init(
        console: ConsoleProtocol,
        prepare: Prepare,
        serve: @escaping ServeFunction
        ) {
        self.console = console
        self.prepare = prepare
        self.serve = serve
    }

    public func run(arguments: [String]) throws {
        try prepare.run(arguments: arguments)

        do {
            try serve()
        } catch ServerError.bind(let host, let port, _) {
            console.error("Could not bind to \(host):\(port), it may be in use or require sudo.")
        } catch {
            console.error("Serve error: \(error)")
        }
    }
}
