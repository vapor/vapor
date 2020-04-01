extension Application {
    public var clients: Clients {
        .init(application: self)
    }
    
    public var client: Client {
        clients.client
    }

    public struct Clients {
        public struct Provider {
            public static var http: Self {
                .init {
                    $0.clients.use { $0.clients.http }
                }
            }

            let run: (Application) -> ()

            public init(_ run: @escaping (Application) -> ()) {
                self.run = run
            }
        }
        
        final class Storage {
            var makeClient: ((Application) -> Client)?
            init() { }
        }
        
        struct Key: StorageKey {
            typealias Value = Storage
        }

        public var http: AsyncHTTPClient {
            return AsyncHTTPClient(eventLoop: self.application.eventLoopGroup.next(), application: self.application)
        }
        
        public var client: Client {
            guard let makeClient = self.storage.makeClient else {
                fatalError("No client configured. Configure with app.clients.use(...)")
            }
            return makeClient(self.application)
        }
        
        public func initialize() {
            self.application.storage[Key.self] = .init()
            self.use(.http)
        }
        
        public func use(_ provider: Provider) {
            provider.run(self.application)
        }

        public func use(_ makeClient: @escaping (Application) -> (Client)) {
            self.storage.makeClient = makeClient
        }

        public let application: Application
        
        private var storage: Storage {
            guard let storage = self.application.storage[Key.self] else {
                fatalError("Clients not configured. Configure with app.clients.initialize()")
            }
            return storage
        }
    }
}
