import ConsoleKit
@preconcurrency import protocol Dispatch.DispatchSourceSignal
import NIOConcurrencyHelpers

/// Boots the application's server. Listens for `SIGINT` and `SIGTERM` for graceful shutdown.
///
///     $ swift run Run serve
///     Server starting on http://localhost:8080
///
public final class ServeCommand: Command, Sendable {
    // This needs to be unchecked because property wrappers
    public struct Signature: CommandSignature, @unchecked Sendable {
        @Option(name: "hostname", short: "H", help: "Set the hostname the server will run on.")
        var hostname: String?
        
        @Option(name: "port", short: "p", help: "Set the port the server will run on.")
        var port: Int?
        
        @Option(name: "bind", short: "b", help: "Convenience for setting hostname and port together.")
        var bind: String?

        @Option(name: "unix-socket", short: nil, help: "Set the path for the unix domain socket file the server will bind to.")
        var socketPath: String?

        public init() { }
    }

    /// Errors that may be thrown when serving a server
    public enum Error: Swift.Error {
        /// Incompatible flags were used together (for instance, specifying a socket path along with a port)
        case incompatibleFlags
    }

    /// See `Command`.
    public let signature = Signature()

    /// See `Command`.
    public var help: String {
        return "Begins serving the app over HTTP."
    }

    private let signalSources: NIOLockedValueBox<[DispatchSourceSignal]>
    private let didShutdown: NIOLockedValueBox<Bool>
    private let server: NIOLockedValueBox<Server?>
    private let running: NIOLockedValueBox<Application.Running?>

    /// Create a new `ServeCommand`.
    init() {
        self.signalSources = .init([])
        self.didShutdown = .init(false)
        self.running = .init(nil)
        self.server = .init(nil)
    }

    /// See `Command`.
    public func run(using context: CommandContext, signature: Signature) throws {
        switch (signature.hostname, signature.port, signature.bind, signature.socketPath) {
        case (.none, .none, .none, .none): // use defaults
            try context.application.server.start(address: nil)
            
        case (.none, .none, .none, .some(let socketPath)): // unix socket
            try context.application.server.start(address: .unixDomainSocket(path: socketPath))
            
        case (.none, .none, .some(let address), .none): // bind ("hostname:port")
            let hostname = address.split(separator: ":").first.flatMap(String.init)
            let port = address.split(separator: ":").last.flatMap(String.init).flatMap(Int.init)
            
            try context.application.server.start(address: .hostname(hostname, port: port))
            
        case (let hostname, let port, .none, .none): // hostname / port
            try context.application.server.start(address: .hostname(hostname, port: port))
            
        default: throw Error.incompatibleFlags
        }
        
        self.server.withLockedValue { $0 = context.application.server }

        // allow the server to be stopped or waited for
        let promise = context.application.eventLoopGroup.next().makePromise(of: Void.self)
        context.application.running = .start(using: promise)
        self.running.withLockedValue { $0 = context.application.running }

        // setup signal sources for shutdown
        let signalQueue = DispatchQueue(label: "codes.vapor.server.shutdown")
        func makeSignalSource(_ code: Int32) {
            let source = DispatchSource.makeSignalSource(signal: code, queue: signalQueue)
            source.setEventHandler {
                print() // clear ^C
                promise.succeed(())
            }
            source.resume()
            self.signalSources.withLockedValue { $0.append(source)
                signal(code, SIG_IGN) }
        }
        makeSignalSource(SIGTERM)
        makeSignalSource(SIGINT)
    }

    func shutdown() {
        self.didShutdown.withLockedValue { $0 = true }
        self.running.withLockedValue { $0?.stop() }
        if let server = self.server.withLockedValue({ $0 }) {
            server.shutdown()
        }
        self.signalSources.withLockedValue { $0.forEach { $0.cancel() } } // clear refs
        self.signalSources.withLockedValue { $0 = [] }
    }
    
    deinit {
        assert(self.didShutdown.withLockedValue { $0 }, "ServeCommand did not shutdown before deinit")
    }
}
