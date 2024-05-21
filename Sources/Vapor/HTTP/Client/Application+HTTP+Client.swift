import AsyncHTTPClient

extension Application.Clients.Provider {
    @available(*, noasync, message: "Don't use from an async context")
    public static var http: Self {
        .init {
            $0.clients.use {
                $0.http.client.shared.delegating(to: $0.eventLoopGroup.next(), logger: $0.logger, byteBufferAllocator: $0.core.storage.allocator)
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

        @available(*, noasync, renamed: "asyncShared", message: "Use the async property instead.")
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
                self.application.storage.set(Key.self, to: new) {
                    try $0.syncShutdown()
                }
                return new
            }
        }
        
        public var asyncShared: HTTPClient {
            get async {
                let lock = self.application.locks.lock(for: Key.self)
                lock.lock()
                if let existing = self.application.storage[Key.self] {
                    lock.unlock()
                    return existing
                }
                
                let new = HTTPClient(
                    eventLoopGroupProvider: .shared(self.application.eventLoopGroup),
                    configuration: self.configuration,
                    backgroundActivityLogger: self.application.logger
                )
                await self.application.storage.setWithAsyncShutdown(Key.self, to: new) {
                    try await $0.shutdown()
                }
                lock.unlock()
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
