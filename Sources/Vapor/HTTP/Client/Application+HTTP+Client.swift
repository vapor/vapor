extension Application.Clients.Provider {
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

        public var shared: HTTPClient {
            let lock = self.application.locks.lock(for: Key.self)
            lock.lock()
            defer { lock.unlock() }
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
