import NIOConcurrencyHelpers

extension Application {
    public var sessions: Sessions {
        .init(application: self)
    }

    public struct Sessions: Sendable {
        final class Storage: Sendable {
            let memory: MemorySessions.Storage
            let configuration: NIOLockedValueBox<SessionsConfiguration>
            init() {
                self.memory = .init()
                self.configuration = .init(.default())
            }
        }

        struct Key: StorageKey {
            typealias Value = Storage
        }

        let application: Application

        public var configuration: SessionsConfiguration {
            get {
                self.storage.configuration.withLockedValue { $0 }
            }
            nonmutating set {
                self.storage.configuration.withLockedValue { $0 = newValue }
            }
        }

        public var middleware: SessionsMiddleware {
            .init(
                session: self.application.sessionDriver,
                configuration: self.configuration
            )
        }

        var storage: Storage {
            guard let storage = self.application.storage[Key.self] else {
                fatalError("Sessions not configured. Configure with app.sessions.initialize()")
            }
            return storage
        }

        func initialize() {
            self.application.storage[Key.self] = .init()
        }
    }
}
