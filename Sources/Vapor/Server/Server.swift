import NIO

public final class Server {
    let application: Application
    let configuration: ServerConfiguration
    let console: Console
    
    public var onShutdown: EventLoopFuture<Void> {
        return self.shutdownPromise!.futureResult
    }
    
    private var signalSources: [DispatchSourceSignal]
    private var shutdownPromise: EventLoopPromise<Void>?
    private var runningServer: HTTPServer?
    private let responder: ServerResponder
    private var didShutdown: Bool
    private var didStart: Bool
    
    init(
        application: Application,
        configuration: ServerConfiguration,
        console: Console
    ) {
        self.application = application
        self.responder = ServerResponder(application: application)
        self.configuration = configuration
        self.console = console
        self.signalSources = []
        self.didStart = false
        self.didShutdown = false
    }
    
    public func start(hostname: String?, port: Int?) throws {
        var configuration = self.configuration
        self.didStart = true
        
        // determine which hostname / port to bind to
        configuration.hostname = hostname ?? self.configuration.hostname
        configuration.port = port ?? self.configuration.port
        
        // print starting message
        self.console.print("Server starting on ", newLine: false)
        let scheme = self.configuration.tlsConfiguration == nil ? "http" : "https"
        self.console.output("\(scheme)://" + configuration.hostname, style: .init(color: .cyan), newLine: false)
        self.console.output(":" + configuration.port.description, style: .init(color: .cyan))
        
        let server = HTTPServer(configuration: configuration, on: self.application.eventLoopGroup)
        let shutdownPromise = self.application.eventLoopGroup.next().makePromise(of: Void.self)
        
        self.application.running = .init(stop: { [unowned self] in
            self.shutdown()
        })
        
        self.shutdownPromise = shutdownPromise
        
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
        try server.start(responder: responder).wait()
        self.runningServer = server
    }
    
    public func shutdown() {
        self.console.print("Requesting server shutdown...")
        let server = self.runningServer!
        do {
            try server.stop().wait()
            self.console.print("Server closed, cleaning up")
        } catch {
            self.console.print("Could not close server: \(error)")
            self.console.print("Cleaning up...")
        }
        self.didShutdown = true
        self.signalSources.forEach { $0.cancel() } // clear refs
        self.signalSources = []
        self.responder.shutdown()
        self.shutdownPromise!.succeed(())
    }
    
    deinit {
        assert(!self.didStart || self.didShutdown, "ServeCommand did not shutdown before deinitializing")
    }
}

private final class ServerResponder: Responder {
    let application: Application
    
    private let responderCache: ThreadSpecificVariable<ThreadResponder>
    private var containers: [Container]
    
    init(application: Application) {
        self.application = application
        self.responderCache = .init()
        self.containers = []
    }
    
    func respond(to request: Request) -> EventLoopFuture<Response> {
        if let responder = self.responderCache.currentValue?.responder {
            return responder.respond(to: request)
        } else {
            return application.makeContainer(on: request.eventLoop).flatMapThrowing { container -> Responder in
                self.containers.append(container)
                let responder = try container.make(Responder.self)
                self.responderCache.currentValue = ThreadResponder(responder: responder)
                return responder
            }.flatMap { responder in
                return responder.respond(to: request)
            }
        }
    }
    
    func shutdown() {
        let containers = self.containers
        self.containers = []
        for container in containers {
            container.shutdown()
        }
    }
}

private final class ThreadResponder {
    var responder: Responder
    init(responder: Responder) {
        self.responder = responder
    }
}
