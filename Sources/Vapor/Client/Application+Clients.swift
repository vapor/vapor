import NIOConcurrencyHelpers

extension Application {
    public var clients: Clients {
        .init(application: self)
    }
    
    public var client: Client {
        guard let makeClient = self.clients.storage.makeClient.withLockedValue({ $0 }) else {
            fatalError("No client configured. Configure with app.clients.use(...)")
        }
        return makeClient(self)
    }

    public struct Clients: Sendable {
        public struct Provider {
            let run: @Sendable (Application) -> ()

            public init(_ run: @Sendable @escaping (Application) -> ()) {
                self.run = run
            }
        }
        
        final class Storage: Sendable {
            let makeClient: NIOLockedValueBox<(@Sendable (Application) -> Client)?>
            init() {
                self.makeClient = .init(nil)
            }
        }
        
        struct Key: StorageKey, Sendable {
            typealias Value = Storage
        }

        func initialize() {
            self.application.storage[Key.self] = .init()
        }
        
        public func use(_ provider: Provider) {
            provider.run(self.application)
        }

        public func use(_ makeClient: @Sendable @escaping (Application) -> (Client)) {
            self.storage.makeClient.withLockedValue { $0 = makeClient }
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
