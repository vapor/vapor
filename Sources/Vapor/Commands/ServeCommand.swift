/// Starts serving the `Application`'s `Responder` over HTTP.
///
///     $ swift run Run serve
///     Server starting on http://localhost:8080
///
public final class ServeCommand: Command {
    /// See `Command`.
    public struct Signature: CommandSignature {
        public let hostname = Option<String>(name: "hostname", short: "H", type: .value, help: "Set the hostname the server will run on.")
        public let port = Option<Int>(name: "port", short: "p",  type: .value, help: "Set the port the server will run on.")
        public let bind = Option<String>(name: "bind", short: "b", type: .value, help: "Convenience for setting hostname and port together.")
    }

    /// See `Command`.
    public let signature = Signature()

    /// See `Command`.
    public var help: String {
        return "Begins serving the app over HTTP."
    }

    private let server: Server
    private var signalSources: [DispatchSourceSignal]

    /// Create a new `ServeCommand`.
    public init(server: Server) {
        self.server = server
        self.signalSources = []
    }

    /// See `Command`.
    public func run(using context: CommandContext<ServeCommand>) throws {
        try self.server.start(
            hostname: context.option(\.hostname)
                // 0.0.0.0:8080, 0.0.0.0, parse hostname
                ?? context.option(\.bind)?.split(separator: ":").first.flatMap(String.init),
            port: context.option(\.port)
                // 0.0.0.0:8080, :8080, parse port
                ?? context.option(\.bind)?.split(separator: ":").last.flatMap(String.init).flatMap(Int.init)
        )
        
        // setup signal sources for shutdown
        let signalQueue = DispatchQueue(label: "codes.vapor.server.shutdown")
        func makeSignalSource(_ code: Int32) {
            let source = DispatchSource.makeSignalSource(signal: code, queue: signalQueue)
            source.setEventHandler {
                print() // clear ^C
                self.server.shutdown()
            }
            source.resume()
            self.signalSources.append(source)
            signal(code, SIG_IGN)
        }
        makeSignalSource(SIGTERM)
        makeSignalSource(SIGINT)
        
        try self.server.onShutdown.wait()
    }
    
    deinit {
        self.signalSources.forEach { $0.cancel() } // clear refs
        self.signalSources = []
    }
}
