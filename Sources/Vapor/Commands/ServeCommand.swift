/// Starts serving the `Application`'s `Responder` over HTTP.
///
///     $ swift run Run serve
///     Server starting on http://localhost:8080
///
public final class ServeCommand: Command {
    /// See `Command`.
    public var arguments: [CommandArgument] {
        return []
    }

    /// See `Command`.
    public var options: [CommandOption] {
        return [
            .value(name: "hostname", short: "H", help: ["Set the hostname the server will run on."]),
            .value(name: "port", short: "p", help: ["Set the port the server will run on."]),
            .value(name: "bind", short: "b", help: ["Convenience for setting hostname and port together."]),
        ]
    }

    /// See `Command`.
    public let help: [String] = ["Begins serving the app over HTTP."]

    /// The server to boot.
    private let config: HTTPServerConfig
    
    private let console: Console
    
    private let application: Application
    
    private var runningServer: HTTPServer?

    /// Create a new `ServeCommand`.
    public init(
        config: HTTPServerConfig,
        console: Console,
        application: Application
    ) {
        self.config = config
        self.console = console
        self.application = application
    }

    /// See `Command`.
    public func run(using context: CommandContext) throws -> EventLoopFuture<Void> {
        return self.start(
            hostname: context.options["hostname"]
                // 0.0.0.0:8080, 0.0.0.0, parse hostname
                ?? context.options["bind"]?.split(separator: ":").first.flatMap(String.init),
            port: context.options["port"].flatMap(Int.init)
                // 0.0.0.0:8080, :8080, parse port
                ?? context.options["bind"]?.split(separator: ":").last.flatMap(String.init).flatMap(Int.init)
        )
    }
    
    private func start(hostname: String?, port: Int?) -> EventLoopFuture<Void> {
        // determine which hostname / port to bind to
        let hostname = hostname ?? self.config.hostname
        let port = port ?? self.config.port
        
        // print starting message
        self.console.print("Server starting on ", newLine: false)
        let scheme = config.tlsConfig == nil ? "http" : "https"
        self.console.output("\(scheme)://" + hostname, style: .init(color: .cyan), newLine: false)
        self.console.output(":" + port.description, style: .init(color: .cyan))
        
        let signalQueue = DispatchQueue(label: "codes.vapor.server.shutdown")
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: signalQueue)
        signalSource.setEventHandler {
            _ = self.runningServer?.close()
            signalSource.cancel()
        }
        let signalSourceTERM = DispatchSource.makeSignalSource(signal: SIGTERM, queue: signalQueue)
        signalSourceTERM.setEventHandler {
            _ = self.runningServer?.close()
            signalSourceTERM.cancel()
        }
        signal(SIGTERM, SIG_IGN)
        signalSourceTERM.resume()
        
        // start the actual HTTPServer
        let server = HTTPServer(config: self.config, on: self.application.eventLoopGroup)
        let delegate = ServerDelegate(application: self.application)
        return server.start(delegate: delegate).flatMap {
            self.runningServer = server
            return server.onClose.map {
                self.console.print("Server shutting down...")
            }
        }
    }
}
