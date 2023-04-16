extension Application {
    public var sessions: Sessions {
        .init(application: self)
    }

    public struct Sessions: Sendable {
        public struct Provider: Sendable {
            public static var memory: Self {
                .init {
                    $0.sessions.use { $0.sessions.memory }
                }
            }

            let run: @Sendable (Application) -> ()

            public init(_ run: @Sendable @escaping (Application) -> ()) {
                self.run = run
            }
        }

        final class Storage {
            let memory: MemorySessions.Storage
            var makeDriver: ((Application) -> SessionDriver)?
            var configuration: SessionsConfiguration
            init() {
                self.memory = .init()
                self.configuration = .default()
            }
        }

        struct Key: StorageKey, Sendable {
            typealias Value = Storage
        }

        let application: Application

        public var configuration: SessionsConfiguration {
            get {
                self.storage.configuration
            }
            nonmutating set {
                self.storage.configuration = newValue
            }
        }

        public var middleware: SessionsMiddleware {
            .init(
                session: self.driver,
                configuration: self.configuration
            )
        }

        public var driver: SessionDriver {
            guard let makeDriver = self.storage.makeDriver else {
                fatalError("No driver configured. Configure with app.sessions.use(...)")
            }
            return makeDriver(self.application)
        }

        public var memory: MemorySessions {
            .init(storage: self.storage.memory)
        }

        public func use(_ provider: Provider) {
            provider.run(self.application)
        }

        public func use(_ makeDriver: @escaping (Application) -> (SessionDriver)) {
            self.storage.makeDriver = makeDriver
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
