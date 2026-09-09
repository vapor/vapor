import NIOConcurrencyHelpers

extension Application {
    public var sessions: Sessions {
        .init(application: self)
    }

    public struct Sessions: Sendable {
        final class Storage: Sendable {
            let memory: MemorySessions.Storage
            init() {
                self.memory = .init()
            }
        }

        struct Key: StorageKey {
            typealias Value = Storage
        }

        let application: Application

        public var middleware: SessionsMiddleware {
            .init(
                session: self.application.sessionDriver,
                configuration: self.application.sessionsConfiguration
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
