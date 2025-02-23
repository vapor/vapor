import AsyncHTTPClient

extension Application.Clients.Provider {
    public static var http: Self {
        .init {
            $0.clients.use {
                $0.http.client.shared.delegating(to: $0.eventLoopGroup.next(), logger: $0.logger, byteBufferAllocator: $0.byteBufferAllocator, contentConfiguration: $0.contentConfiguration)
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

        public var shared: HTTPClient {
            self.application.locks.lock(for: Key.self).withLock {
                if let existing = self.application.storage[Key.self] {
                    return existing
                }
                let new = HTTPClient(
                    eventLoopGroupProvider: .shared(self.application.eventLoopGroup),
                    configuration: self.configuration,
                    backgroundActivityLogger: self.application.logger
                )
                self.application.storage.setFirstTime(Key.self, to: new, onShutdown: { try $0.syncShutdown() }) {
                    try await $0.shutdown()
                }
                return new
            }
        }

        public var configuration: HTTPClient.Configuration {
            get {
                self.application.storage[ConfigurationKey.self] ?? .init()
            }
            nonmutating set {
                if self.application.storage.contains(Key.self) {
                    self.application.logger.warning("Cannot modify client configuration after client has been used.")
                } else {
                    self.application.storage[ConfigurationKey.self] = newValue
                }
            }
        }

        struct Key: StorageKey, LockKey {
            typealias Value = HTTPClient
        }

        struct ConfigurationKey: StorageKey {
            typealias Value = HTTPClient.Configuration
        }
    }
}
