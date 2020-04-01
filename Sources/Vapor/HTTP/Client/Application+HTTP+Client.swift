extension Application.HTTP {
    public var client: Client {
        .init(application: self.application)
    }

    public struct Client {
        let application: Application

        public var shared: HTTPClient {
            if let existing = self.application.storage[Key.self] {
                return existing
            } else {
                let lock = self.application.locks.lock(for: Key.self)
                lock.lock()
                defer { lock.unlock() }
                if let existing = self.application.storage[Key.self] {
                    return existing
                }
                let new = HTTPClient(
                    eventLoopGroupProvider: .shared(self.application.eventLoopGroup),
                    configuration: self.configuration
                )
                self.application.storage.set(Key.self, to: new) {
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
