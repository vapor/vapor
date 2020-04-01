import AsyncHTTPClient

extension Application.Clients.Provider {
    public static var http: Self {
        .init {
            $0.clients.use {
                DelegatingHTTPClient(
                    eventLoop: $0.eventLoopGroup.next(),
                    http: $0.http.client.current
                )
            }
        }
    }
}

extension Application.HTTP {
    public var client: Client {
        .init(application: self.application)
    }

    public struct Client {
        let application: Application

        public var current: HTTPClient {
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

        public var configuration: HTTPClient.Configuration {
            get {
                self.application.storage[ConfigurationKey.self] ?? .init()
            }
            nonmutating set {
                if self.application.storage.contains(ClientKey.self) {
                    self.application.logger.warning("Cannot modify client configuration after client has been used")
                } else {
                    self.application.storage[ConfigurationKey.self] = newValue
                }
            }
        }

        struct ClientKey: StorageKey, LockKey {
            typealias Value = HTTPClient
        }

        struct ConfigurationKey: StorageKey {
            typealias Value = HTTPClient.Configuration
        }
    }
}

private struct DelegatingHTTPClient: Client {
    let eventLoop: EventLoop
    let http: HTTPClient

    func send(
        _ client: ClientRequest
    ) -> EventLoopFuture<ClientResponse> {
        do {
            let request = try HTTPClient.Request(
                url: URL(string: client.url.string)!,
                method: client.method,
                headers: client.headers,
                body: client.body.map { .byteBuffer($0) }
            )
            return self.http.execute(
                request: request,
                eventLoop: .delegate(on: self.eventLoop)
            ).map { response in
                let client = ClientResponse(
                    status: response.status,
                    headers: response.headers,
                    body: response.body
                )
                return client
            }
        } catch {
            return self.eventLoop.makeFailedFuture(error)
        }
    }

    func delegating(to eventLoop: EventLoop) -> Client {
        DelegatingHTTPClient(eventLoop: eventLoop, http: self.http)
    }
}
