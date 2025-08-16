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
            let running: Application.Running.Storage
            let directory: NIOLockedValueBox<DirectoryConfiguration>

            init() {
                self.console = .init(Terminal())
                self.commands = .init(Commands())
                var asyncCommands = AsyncCommands()
                asyncCommands.use(BootCommand(), as: "boot")
                self.asyncCommands = .init(AsyncCommands())
                self.running = .init()
                self.directory = .init(.detect())
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
        }
    }
}
