/// Starts serving the `Application`'s `Responder` over HTTP.
///
///     $ swift run Run serve
///     Server starting on http://localhost:8080
///
public struct ServeCommand: Command {
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
    
    private var application: Application

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
        
        let app = self.application
        let server = HTTPServer(config: self.config, on: app.eventLoopGroup)
        let delegate = ServerDelegate(application: app)
        
        let eventLoop = app.eventLoopGroup.next()
        let onShutdown = eventLoop.makePromise(of: Void.self)
        
        var runningServer: HTTPServer?
        let console = self.console
        
        func initiateShutdown() {
            app.running = nil // stop ref cycle
            console.print("Requesting server shutdown...")
            let server = runningServer!
            server.shutdown().flatMap { _ -> EventLoopFuture<Void> in
                console.print("Server closed, cleaning up")
                return .andAllSucceed(
                    delegate.containers.map { $0.willShutdown() },
                    on: eventLoop
                )
            }.cascade(to: onShutdown)
        }
        #warning("TODO: shutdown w/o ref cycle")
        app.running = .init(stop: initiateShutdown)
        
        // setup signal sources for shutdown
        let signalQueue = DispatchQueue(label: "codes.vapor.server.shutdown")
        var sources: [DispatchSourceSignal] = []
        func makeSignalSource(_ code: Int32) {
            let source = DispatchSource.makeSignalSource(signal: code, queue: signalQueue)
            source.setEventHandler {
                print() // clear ^C
                initiateShutdown()
                sources.forEach { $0.cancel() }
            }
            source.resume()
            sources.append(source)
            signal(code, SIG_IGN)
        }
        makeSignalSource(SIGTERM)
        makeSignalSource(SIGINT)
        
        // start the actual HTTPServer
        return server.start(delegate: delegate).flatMap {
            runningServer = server
            return onShutdown.futureResult
        }
    }
}
