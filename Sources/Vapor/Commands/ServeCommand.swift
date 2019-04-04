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

    private let configuration: ServerConfiguration
    private let console: Console
    private weak var application: Application?
    
    private var signalSources: [DispatchSourceSignal]
    private var runningServer: HTTPServer?
    private var onShutdown: EventLoopPromise<Void>?
    private var responder: ServerResponder?
    private var didShutdown: Bool
    private var didStart: Bool

    /// Create a new `ServeCommand`.
    public init(
        configuration: ServerConfiguration,
        console: Console,
        application: Application
    ) {
        self.configuration = configuration
        self.console = console
        self.application = application
        self.signalSources = []
        self.didShutdown = false
        self.didStart = false
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
        self.didStart = true
        
        // determine which hostname / port to bind to
        let hostname = hostname ?? self.configuration.hostname
        let port = port ?? self.configuration.port
        
        // print starting message
        self.console.print("Server starting on ", newLine: false)
        let scheme = self.configuration.tlsConfig == nil ? "http" : "https"
        self.console.output("\(scheme)://" + hostname, style: .init(color: .cyan), newLine: false)
        self.console.output(":" + port.description, style: .init(color: .cyan))
        
        guard let app = self.application else {
            fatalError("Application deinitialized")
        }
        let eventLoop = app.eventLoopGroup.next()
        let server = HTTPServer(configuration: self.configuration, on: app.eventLoopGroup)
        let responder = ServerResponder(application: app, on: eventLoop)
        
        let onShutdown = eventLoop.makePromise(of: Void.self)
        
        app.running = .init(stop: {
            self.shutdown()
        })
        
        self.onShutdown = onShutdown
        self.responder = responder
        self.runningServer = server
        
        // setup signal sources for shutdown
        let signalQueue = DispatchQueue(label: "codes.vapor.server.shutdown")
        func makeSignalSource(_ code: Int32) {
            let source = DispatchSource.makeSignalSource(signal: code, queue: signalQueue)
            source.setEventHandler {
                print() // clear ^C
                self.shutdown()
            }
            source.resume()
            self.signalSources.append(source)
            signal(code, SIG_IGN)
        }
        makeSignalSource(SIGTERM)
        makeSignalSource(SIGINT)
        
        
        // start the actual HTTPServer
        return server.start(responder: responder).flatMap {
            self.runningServer = server
            return onShutdown.futureResult
        }
    }
    
    func shutdown() {
        console.print("Requesting server shutdown...")
        let server = self.runningServer!
        server.shutdown().flatMap { _ -> EventLoopFuture<Void> in
            self.console.print("Server closed, cleaning up")
            return self._shutdown()
        }.flatMapError { error in
            self.console.print("Could not close server: \(error)")
            self.console.print("Cleaning up...")
            return self._shutdown()
        }.cascade(to: self.onShutdown!)
    }
    
    func _shutdown() -> EventLoopFuture<Void> {
        self.didShutdown = true
        self.signalSources.forEach { $0.cancel() } // clear refs
        self.signalSources = []
        return self.responder!.shutdown()
    }
    
    deinit {
        assert(!self.didStart || self.didShutdown, "ServeCommand did not shutdown before deinitializing")
    }
}
