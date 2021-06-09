extension Application {
    public var console: Console {
        get { self.core.storage.console }
        set { self.core.storage.console = newValue }
    }

    public var commands: Commands {
        get { self.core.storage.commands }
        set { self.core.storage.commands = newValue }
    }

    /// The application thread pool. Vapor provides a thread pool with 64 threads by default.
    ///
    /// It's possible to configure the thread pool size by overriding this value with your own thread pool.
    ///
    /// ```
    /// application.threadPool = NIOThreadPool(numberOfThreads: 100)
    /// ```
    ///
    /// If overriden, Vapor will take ownership of the thread pool and automatically start it and shut it down when needed.
    ///
    /// - Warning: Can only be set during application setup/initialization.
    public var threadPool: NIOThreadPool {
        get { self.core.storage.threadPool }
        set {
            guard !self.isBooted else {
                self.logger.critical("Cannot replace thread pool after application has booted")
                fatalError("Cannot replace thread pool after application has booted")
            }
            
            try! self.core.storage.threadPool.syncShutdownGracefully()
            self.core.storage.threadPool = newValue
            self.core.storage.threadPool.start()
        }
    }
    
    public var fileio: NonBlockingFileIO {
        .init(threadPool: self.threadPool)
    }

    public var allocator: ByteBufferAllocator {
        self.core.storage.allocator
    }

    public var running: Running? {
        get { self.core.storage.running.current }
        set { self.core.storage.running.current = newValue }
    }

    public var directory: DirectoryConfiguration {
        get { self.core.storage.directory }
        set { self.core.storage.directory = newValue }
    }

    internal var core: Core {
        .init(application: self)
    }

    public struct Core {
        final class Storage {
            var console: Console
            var commands: Commands
            var threadPool: NIOThreadPool
            var allocator: ByteBufferAllocator
            var running: Application.Running.Storage
            var directory: DirectoryConfiguration

            init() {
                self.console = Terminal()
                self.commands = Commands()
                self.commands.use(BootCommand(), as: "boot")
                self.threadPool = NIOThreadPool(numberOfThreads: 64)
                self.threadPool.start()
                self.allocator = .init()
                self.running = .init()
                self.directory = .detect()
            }
        }

        struct LifecycleHandler: Vapor.LifecycleHandler {
            func shutdown(_ application: Application) {
                try! application.threadPool.syncShutdownGracefully()
            }
        }

        struct Key: StorageKey {
            typealias Value = Storage
        }

        let application: Application

        var storage: Storage {
            guard let storage = self.application.storage[Key.self] else {
                fatalError("Core not configured. Configure with app.core.initialize()")
            }
            return storage
        }

        func initialize() {
            self.application.storage[Key.self] = .init()
            self.application.lifecycle.use(LifecycleHandler())
        }
    }
}
