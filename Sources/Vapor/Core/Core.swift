import ConsoleKit
import NIOCore
import NIOPosix
import NIOConcurrencyHelpers

extension Application {
    public var console: any Console {
        get { self.core.storage.console.withLockedValue { $0 } }
        set { self.core.storage.console.withLockedValue { $0 = newValue } }
    }

    public var commands: Commands {
        get { self.core.storage.commands.withLockedValue { $0 } }
        set { self.core.storage.commands.withLockedValue { $0 = newValue } }
    }

    public var asyncCommands: AsyncCommands {
        get { self.core.storage.asyncCommands.withLockedValue { $0 } }
        set { self.core.storage.asyncCommands.withLockedValue { $0 = newValue } }
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
                do {
                    try $0.syncShutdownGracefully()
                } catch is NIOThreadPoolError.UnsupportedOperation {
                    // ignore, singleton thread pool throws this error on shutdown attempts
                    // see https://github.com/apple/swift-nio/blob/c51907a839e63ebf0ba2076bba73dd96436bd1b9/Sources/NIOPosix/NIOThreadPool.swift#L142-L147
                } catch {
                    fatalError("Unexpected error shutting down old thread pool")
                }
                $0 = newValue
                $0.start()
            })
        }
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
            let console: NIOLockedValueBox<any Console>
            let commands: NIOLockedValueBox<Commands>
            let asyncCommands: NIOLockedValueBox<AsyncCommands>
            let threadPool: NIOLockedValueBox<NIOThreadPool>
            let running: Application.Running.Storage
            let directory: NIOLockedValueBox<DirectoryConfiguration>

            init() {
                self.console = .init(Terminal())
                self.commands = .init(Commands())
                var asyncCommands = AsyncCommands()
                asyncCommands.use(BootCommand(), as: "boot")
                self.asyncCommands = .init(AsyncCommands())
                let threadPool = NIOSingletons.posixBlockingThreadPool
                threadPool.start()
                self.threadPool = .init(threadPool)
                self.running = .init()
                self.directory = .init(.detect())
            }
        }
        
        struct AsyncLifecycleHandler: Vapor.LifecycleHandler {
            func shutdownAsync(_ application: Application) async {
                do {
                    try await application.threadPool.shutdownGracefully()
                } catch is NIOThreadPoolError.UnsupportedOperation {
                    // ignore, singleton thread pool throws this error on shutdown attempts
                    // see https://github.com/apple/swift-nio/blob/c51907a839e63ebf0ba2076bba73dd96436bd1b9/Sources/NIOPosix/NIOThreadPool.swift#L142-L147
                } catch {
                    application.logger.debug("Failed to shutdown thread pool", metadata: ["error": "\(error)"])
                }
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
            self.application.lifecycle.use(AsyncLifecycleHandler())
        }
    }
}
