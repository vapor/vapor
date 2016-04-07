/** Command to start the server */
public class ServeCommand: Command {
    public let console: Console
    public let name = "serve"
    public var help: String? = "Serve the application"

    public var options: [InputOption] {
        return [
            InputOption("ip",
                mode: .Optional,
                help: "The ip to serve the application on.",
                value: "0.0.0.0"
            ),

            InputOption("port",
                mode: .Optional,
                help: "The port to serve the application on.",
                value: String(app.config.get("app.port", 8080))
            )
        ]
    }

    public required init(console: Console) {
        self.console = console
    }

    public func handle(input: Input) throws {
        let ip = input.option("ip")
        let port: Int

        if let value = input.option("port")?.int {
            port = value
        } else {
            port = 8080
        }

        do {
            comment("Visit http://\(ip == "0.0.0.0" ? "localhost" : (ip ?? "localhost")):\(port)")
            try app.serve(ip: ip ?? "0.0.0.0", port: port)
        } catch {
            Log.error("Server start error: \(error)")
        }
    }

}
