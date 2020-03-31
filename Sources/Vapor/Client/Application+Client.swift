extension Application {
    public var clients: Clients {
        .init(application: self)
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

        struct ConfigurationKey: StorageKey {
            typealias Value = HTTPClient.Configuration
        }

        public var configuration: HTTPClient.Configuration {
            get {
                self.application.storage[ConfigurationKey.self] ?? .init()
            }
            nonmutating set {
                if self.application.storage.contains(ClientKey.self) {
                    self.application.logger.warning("Cannot modify client configuration after client has been used")
                }
                self.application.storage[ConfigurationKey.self] = newValue
            }
        }
        
        final class Storage {
            var makeClient: ((Application) -> Client)?
            init() { }
        }

        struct ClientKey: StorageKey, LockKey {
            typealias Value = WrappedHTTPClient
        }
        
        struct Key: StorageKey {
            typealias Value = Storage
        }

        public var http: WrappedHTTPClient {
            if let existing = self.application.storage[ClientKey.self] {
                return existing
            } else {
                let lock = self.application.locks.lock(for: ClientKey.self)
                lock.lock()
                defer { lock.unlock() }
                if let existing = self.application.storage[ClientKey.self] {
                    return existing
                }
                let new = HTTPClient(
                    eventLoopGroupProvider: .shared(self.application.eventLoopGroup),
                    configuration: self.configuration
                )
                let wrapped = WrappedHTTPClient(http: new, eventLoop: self.application.eventLoopGroup.next())
                self.application.storage.set(ClientKey.self, to: wrapped) {
                    try $0.http.syncShutdown()
                }
                return wrapped
            }
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
                fatalError("Clients not configured. Configure with app.client.initialize()")
            }
            return storage
        }
    }
}

//extension HTTPClient: Client {
//    public func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
//        self.send(request, eventLoop: .indifferent)
//    }
//    
//    public func `for`(_ request: Vapor.Request) -> Client {
//        return HTTPClient(eventLoopGroupProvider: .shared(request.eventLoop))
//    }
//}
