import NIOCore
import NIOPosix
import NIOConcurrencyHelpers

extension Application {
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
            let running: Application.Running.Storage
            let directory: NIOLockedValueBox<DirectoryConfiguration>

            init() {
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
