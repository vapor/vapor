import NIOConcurrencyHelpers

extension Application {
    public var asyncSessions: AsyncSessions {
        .init(application: self)
    }

    public struct AsyncSessions: Sendable {
        public struct Provider: Sendable {
            public static var memory: Self {
                .init {
                    $0.asyncSessions.use { $0.asyncSessions.memory }
                }
            }

            let run: @Sendable (Application) -> ()

            public init(_ run: @Sendable @escaping (Application) -> ()) {
                self.run = run
            }
        }

        final class Storage: Sendable {
            struct SessionDriverFactory {
                let factory: (@Sendable (Application) -> AsyncSessionDriver)?
            }
            let memory: AsyncMemorySessions.Storage
            let makeDriver: NIOLockedValueBox<SessionDriverFactory>
            let configuration: NIOLockedValueBox<SessionsConfiguration>
            init() {
                self.memory = .init()
                self.configuration = .init(.default())
                self.makeDriver = .init(.init(factory: nil))
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

        public var middleware: AsyncSessionsMiddleware {
            .init(
                session: self.driver,
                configuration: self.configuration
            )
        }

        public var driver: AsyncSessionDriver {
            guard let makeDriver = self.storage.makeDriver.withLockedValue({ $0.factory }) else {
                fatalError("No driver configured. Configure with app.asyncSessions.use(...)")
            }
            return makeDriver(self.application)
        }

        public var memory: AsyncMemorySessions {
            .init(storage: self.storage.memory)
        }

        public func use(_ provider: Provider) {
            provider.run(self.application)
        }

        @preconcurrency public func use(_ makeDriver: @Sendable @escaping (Application) -> (AsyncSessionDriver)) {
            self.storage.makeDriver.withLockedValue { $0 = .init(factory: makeDriver) }
        }

        var storage: Storage {
            guard let storage = self.application.storage[Key.self] else {
                fatalError("Sessions not configured. Configure with app.asyncSessions.initialize()")
            }
            return storage
        }

        func initialize() {
            self.application.storage[Key.self] = .init()
        }
    }
}
