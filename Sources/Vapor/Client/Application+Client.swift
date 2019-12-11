extension Application {
    public var client: Client {
        .init(application: self)
    }

    public struct Client {
        public var eventLoopGroup: EventLoopGroup {
            self.application.eventLoopGroup
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

        struct ClientKey: StorageKey, LockKey {
            typealias Value = HTTPClient
        }

        public var http: HTTPClient {
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
                self.application.storage.set(ClientKey.self, to: new) {
                    try $0.syncShutdown()
                }
                return new
            }
        }

        let application: Application
    }
}

extension Application.Client: Client {
    public func `for`(_ request: Request) -> Client {
        RequestClient(http: self.http, req: request)
    }

    public func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        self.http.send(request, eventLoop: .indifferent)
    }
}
