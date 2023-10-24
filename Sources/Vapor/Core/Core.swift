@preconcurrency import ConsoleKit
import NIOCore
import NIOPosix
import NIOConcurrencyHelpers

extension Application {
    public var console: Console {
        get { self.core.storage.console.withLockedValue { $0 } }
        set { self.core.storage.console.withLockedValue { $0 = newValue } }
    }

    public var commands: Commands {
        get { self.core.storage.commands.withLockedValue { $0 } }
        set { self.core.storage.commands.withLockedValue { $0 = newValue } }
    }

    /// The application thread pool. Vapor provides a thread pool with 64 threads by default.
    ///
    /// It's possible to configure the thread pool size by overriding this value with your own thread pool.
    ///
    /// ```
    /// application.threadPool = NIOThreadPool(numberOfThreads: 100)
    /// ```
    ///
    /// If overridden, Vapor will take ownership of the thread pool and automatically start it and shut it down when needed.
    ///
    /// - Warning: Can only be set during application setup/initialization.
    public var threadPool: NIOThreadPool {
        get { self.core.storage.threadPool.withLockedValue { $0 } }
        set {
            guard !self.isBooted.withLockedValue({ $0 }) else {
                self.logger.critical("Cannot replace thread pool after application has booted")
                fatalError("Cannot replace thread pool after application has booted")
            }
            
            self.core.storage.threadPool.withLockedValue({
                try! $0.syncShutdownGracefully()
                $0 = newValue
                $0.start()
            })
        }
    }
    
    public var fileio: NonBlockingFileIO {
        .init(threadPool: self.threadPool)
    }

    public var allocator: ByteBufferAllocator {
        self.core.storage.allocator
    }

    public var running: Running? {
        get { self.core.storage.running.current.withLockedValue { $0 } }
        set { self.core.storage.running.current.withLockedValue { $0 = newValue } }
    }

    public var directory: DirectoryConfiguration {
        get { self.core.storage.directory.withLockedValue { $0 } }
        set { self.core.storage.directory.withLockedValue { $0 = newValue } }
    }

    internal var core: Core {
        .init(application: self)
    }

    public struct Core: Sendable {
        final class Storage: Sendable {
            let console: NIOLockedValueBox<Console>
            let commands: NIOLockedValueBox<Commands>
            let threadPool: NIOLockedValueBox<NIOThreadPool>
            let allocator: ByteBufferAllocator
            let running: Application.Running.Storage
            let directory: NIOLockedValueBox<DirectoryConfiguration>

            init() {
                self.console = .init(Terminal())
                var commands = Commands()
                commands.use(BootCommand(), as: "boot")
                self.commands = .init(commands)
                let threadPool = NIOThreadPool(numberOfThreads: System.coreCount)
                threadPool.start()
                self.threadPool = .init(threadPool)
                self.allocator = .init()
                self.running = .init()
                self.directory = .init(.detect())
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
