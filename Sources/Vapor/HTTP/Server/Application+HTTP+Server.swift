extension Application.HTTP {
    public var server: Server {
        .init(application: self.application)
    }
    
    public struct Server {
        let application: Application

        public var configuration: HTTPServer.Configuration {
            get {
                self.application.storage[ConfigurationKey.self] ?? .init()
            }
            nonmutating set {
                if self.application.storage.contains(Key.self) {
                    self.application.logger.warning("Cannot modify server configuration after server has been used")
                } else {
                    self.application.storage[ConfigurationKey.self] = newValue
                }
            }
        }

        struct Key: StorageKey, LockKey {
            typealias Value = HTTPClient
        }

        struct ConfigurationKey: StorageKey {
            typealias Value = HTTPServer.Configuration
        }
    }
}
