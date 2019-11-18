struct CoreStorage {
    var routes: Routes
    var middleware: MiddlewareConfiguration
    var commands: CommandConfiguration
    var server: Server
    var console: Console
    var threadPool: NIOThreadPool
    var running: RunningService
    var fileio: NonBlockingFileIO
    var allocator: ByteBufferAllocator
    var client: HTTPClient
    var sessions: Sessions
    let serveCommand: ServeCommand
    var directory: DirectoryConfiguration
    
    init(_ app: Application) {
        self.routes = .init()
        self.middleware = .init()
        self.server = .init(app)
        self.commands = .init()
        self.console = Terminal()
        self.threadPool = NIOThreadPool(numberOfThreads: 1)
        self.threadPool.start()
        self.running = .init()
        self.fileio = .init(threadPool: self.threadPool)
        self.allocator = .init()
        self.client = HTTPClient(
            eventLoopGroupProvider: .shared(app.eventLoopGroup),
            configuration: .init()
        )
        self.sessions = MemorySessions(storage: .init())
        self.serveCommand = ServeCommand(application: app)
        self.directory = DirectoryConfiguration.detect()
        
        self.middleware.use(ErrorMiddleware.default(environment: app.environment))
        
        self.commands.use(self.serveCommand, as: "serve", isDefault: true)
        self.commands.use(RoutesCommand(application: app), as: "routes")
        self.commands.use(BootCommand(), as: "boot")
    }
    
    func shutdown() {
        self.serveCommand.shutdown()
        try! self.client.syncShutdown()
        try! self.threadPool.syncShutdownGracefully()
    }
}
