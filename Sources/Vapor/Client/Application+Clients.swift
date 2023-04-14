extension Application {
    public var clients: Clients {
        .init(application: self)
    }
    
    public var client: Client {
        guard let makeClient = self.clients.storage.makeClient else {
            fatalError("No client configured. Configure with app.clients.use(...)")
        }
        return makeClient(self)
    }

    public struct Clients: Sendable {
        public struct Provider: Sendable {
            let run: (Application) -> ()

            public init(_ run: @escaping (Application) -> ()) {
                self.run = run
            }
        }
        
        final class Storage {
            var makeClient: ((Application) -> Client)?
            init() { }
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

        public func use(_ makeClient: @escaping (Application) -> (Client)) {
            self.storage.makeClient = makeClient
        }

        public let application: Application
        
        var storage: Storage {
            guard let storage = self.application.storage[Key.self] else {
                fatalError("Clients not initialized. Initialize with app.clients.initialize()")
            }
            return storage
        }
    }
}
