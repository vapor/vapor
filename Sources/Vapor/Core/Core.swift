import ConsoleKit
import NIOCore
import NIOPosix
import NIOConcurrencyHelpers

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
    /// If overridden, Vapor will take ownership of the thread pool and automatically start it and shut it down when needed.
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

    public struct Core: Sendable {
        final class Storage: @unchecked Sendable {
            var console: Console {
                get {
                    storageLock.withLock {
                        return _console
                    }
                }
                set {
                    storageLock.withLockVoid {
                        _console = newValue
                    }
                }
            }
            var commands: Commands {
                get {
                    storageLock.withLock {
                        return _commands
                    }
                }
                set {
                    storageLock.withLockVoid {
                        _commands = newValue
                    }
                }
            }
            var threadPool: NIOThreadPool {
                get {
                    storageLock.withLock {
                        return _threadPool
                    }
                }
                set {
                    storageLock.withLockVoid {
                        _threadPool = newValue
                    }
                }
            }
            var allocator: ByteBufferAllocator {
                get {
                    storageLock.withLock {
                        return _allocator
                    }
                }
                set {
                    storageLock.withLockVoid {
                        _allocator = newValue
                    }
                }
            }
            var running: Application.Running.Storage {
                get {
                    storageLock.withLock {
                        return _running
                    }
                }
                set {
                    storageLock.withLockVoid {
                        _running = newValue
                    }
                }
            }
            var directory: DirectoryConfiguration {
                get {
                    storageLock.withLock {
                        return _directory
                    }
                }
                set {
                    storageLock.withLockVoid {
                        _directory = newValue
                    }
                }
            }
            
            private var _console: Console
            private var _commands: Commands
            private var _threadPool: NIOThreadPool
            private var _allocator: ByteBufferAllocator
            private var _running: Application.Running.Storage
            private var _directory: DirectoryConfiguration
            private let storageLock: NIOLock

            init() {
                self.storageLock = .init()
                self._console = Terminal()
                self._commands = Commands()
                self._commands.use(BootCommand(), as: "boot")
                self._threadPool = NIOThreadPool(numberOfThreads: 64)
                self._threadPool.start()
                self._allocator = .init()
                self._running = .init()
                self._directory = .detect()
            }
        }

        struct LifecycleHandler: Sendable, Vapor.LifecycleHandler {
            func shutdown(_ application: Application) {
                try! application.threadPool.syncShutdownGracefully()
            }
        }

        struct Key: Sendable, StorageKey {
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
