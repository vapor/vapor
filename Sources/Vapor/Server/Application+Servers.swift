import NIOConcurrencyHelpers

extension Application {
    public var servers: Servers {
        .init(application: self)
    }

    public var server: Server {
        guard let makeServer = self.servers.storage.makeServer.withLockedValue({ $0.factory }) else {
            fatalError("No server configured. Configure with app.servers.use(...)")
        }
        return makeServer(self)
    }

    public struct Servers: Sendable {
        public struct Provider {
            let run: @Sendable (Application) -> ()

            @preconcurrency public init(_ run: @Sendable @escaping (Application) -> ()) {
                self.run = run
            }
        }

        struct CommandKey: StorageKey {
            typealias Value = ServeCommand
        }

        final class Storage: Sendable {
            struct ServerFactory {
                let factory: (@Sendable (Application) -> Server)?
            }
            let makeServer: NIOLockedValueBox<ServerFactory>
            init() {
                self.makeServer = .init(.init(factory: nil))
            }
        }

        struct Key: StorageKey {
            typealias Value = Storage
        }

        func initialize() {
            self.application.storage[Key.self] = .init()
        }

        public func use(_ provider: Provider) {
            provider.run(self.application)
        }

        @preconcurrency public func use(_ makeServer: @Sendable @escaping (Application) -> (Server)) {
            self.storage.makeServer.withLockedValue { $0 = .init(factory: makeServer) }
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
