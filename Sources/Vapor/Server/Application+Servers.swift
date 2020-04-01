extension Application {
    public var servers: Servers {
        .init(application: self)
    }

    public var server: Server {
        if let existing = self.servers.current {
            return existing
        } else {
            let new = self.servers.make()
            self.servers.current = new
            return new
        }
    }

    public struct Servers {
        public struct Provider {
            let run: (Application) -> ()

            public init(_ run: @escaping (Application) -> ()) {
                self.run = run
            }
        }

        struct CommandKey: StorageKey {
            typealias Value = ServeCommand
        }

        final class Storage {
            var makeServer: ((Application) -> Server)?
            var current: Server?
            init() { }
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

        func make() -> Server {
            guard let makeServer = self.storage.makeServer else {
                fatalError("No server configured. Configure with app.servers.use(...)")
            }
            return makeServer(self.application)
        }

        var current: Server? {
            get {
                self.storage.current
            }
            nonmutating set {
                self.storage.current = newValue
            }
        }

        public func use(_ makeServer: @escaping (Application) -> (Server)) {
            self.storage.makeServer = makeServer
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
