import enum Engine.ServerError
import Console

/**
    Serves the droplet.
*/
public class Serve: Command {
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
        serve: ServeFunction
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
