extension Application {
    public var console: Console {
        get { self.core.console }
        set { self.core.console = newValue }
    }
    
    public var commands: Commands {
        get { self.core.commands }
        set { self.core.commands = newValue }
    }
    
    public var threadPool: NIOThreadPool {
        self.core.threadPool
    }
    public var fileio: NonBlockingFileIO {
        .init(threadPool: self.threadPool)
    }
    
    public var allocator: ByteBufferAllocator {
        self.core.allocator
    }
    
    public var running: Running? {
        get { self.core.running.current }
        set { self.core.running.current = newValue }
    }
    
    public var directory: DirectoryConfiguration {
        get { self.core.directory }
        set { self.core.directory = newValue }
    }
    
    var core: Core {
        self.providers.require(Core.self)
    }
}

final class Core: Provider {
    var console: Console
    var commands: Commands
    var threadPool: NIOThreadPool
    var allocator: ByteBufferAllocator
    var running: RunningService
    var directory: DirectoryConfiguration
    public let application: Application
    
    public init(_ application: Application) {
        self.application = application
        self.console = Terminal()
        self.commands = Commands()
        commands.use(BootCommand(), as: "boot")
        self.threadPool = NIOThreadPool(numberOfThreads: 1)
        self.threadPool.start()
        self.allocator = .init()
        self.running = .init()
        self.directory = .detect()
    }
    
    func shutdown() {
        try! self.threadPool.syncShutdownGracefully()
    }
}
