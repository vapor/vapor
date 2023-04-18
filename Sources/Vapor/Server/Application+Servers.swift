import NIOConcurrencyHelpers

extension Application {
    public var servers: Servers {
        .init(application: self)
    }

    public var server: Server {
        let closure = self.servers.storage.makeServer.withLockedValue { $0 }
        guard let makeServer = closure else {
            fatalError("No server configured. Configure with app.servers.use(...)")
        }
        return makeServer(self)
    }

    public struct Servers: Sendable {
        public struct Provider: Sendable {
            let run: @Sendable (Application) -> ()

            public init(_ run: @Sendable @escaping (Application) -> ()) {
                self.run = run
            }
        }

        struct CommandKey: Sendable, StorageKey {
            typealias Value = ServeCommand
        }

        final class Storage: Sendable {
            let makeServer: NIOLockedValueBox<(@Sendable (Application) -> Server)?>
            init() {
                makeServer = .init(nil)
            }
        }

        struct Key: Sendable, StorageKey {
            typealias Value = Storage
        }

        func initialize() {
            self.application.storage[Key.self] = .init()
        }

        public func use(_ provider: Provider) {
            provider.run(self.application)
        }

        public func use(_ makeServer: @Sendable @escaping (Application) -> (Server)) {
            self.storage.makeServer.withLockedValue { $0 = makeServer }
        }

        public var command: ServeCommand {
            if let existing = self.application.storage.get(CommandKey.self) {
                return existing
            } else {
                let new = ServeCommand()
                self.application.storage.set(CommandKey.self, to: new) {
                    $0.shutdown()
                }
                return new
            }
        }

        let application: Application

        var storage: Storage {
            guard let storage = self.application.storage[Key.self] else {
                fatalError("Servers not initialized. Configure with app.servers.initialize()")
            }
            return storage
        }
    }
}
