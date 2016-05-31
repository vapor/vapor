///** Command to start the server */
//public class ServeCommand: Command {
//
//    /// Console this command is registered to
//    public let console: Console
//
//    /// Name of the command
//    public let name = "serve"
//
//    /// Optional help info for the command
//    public let help: String? = "Serve the application"
//
//    /// Options for this command
//    public var options: [InputOption] {
//        return [
//            InputOption("ip",
//                mode: .Optional,
//                help: "The ip to serve the application on.",
//                value: "0.0.0.0"
//            ),
//
//            InputOption("port",
//                mode: .Optional,
//                help: "The port to serve the application on.",
//                value: String(app.config.get("app.port", 8080))
//            )
//        ]
//    }
//
//    /**
//        Initialize the command
//        - parameter console: Console instance this command will be registered on
//    */
//    public required init(console: Console) {
//        self.console = console
//    }
//
//    /**
//        Called by `run()` after input has been compiled
//        - parameter input: CLI input
//        - throws: Console.Error
//    */
//    public func handle(input: Input) throws {
//        let ip = input.option("ip")
//        let port: Int
//
//        if let value = input.option("port")?.int {
//            port = value
//        } else {
//            port = 8080
//        }
//
//        do {
//            comment("Visit http://\(ip == "0.0.0.0" ? "localhost" : (ip ?? "localhost")):\(port)")
//            try app.serve(ip: ip ?? "0.0.0.0", port: port)
//        } catch {
//            Log.error("Server start error: \(error)")
//        }
//    }
//
//}
