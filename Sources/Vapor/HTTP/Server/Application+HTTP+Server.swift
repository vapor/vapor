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
                self.application.storage[ConfigurationKey.self] = newValue
            }
        }

        struct ConfigurationKey: StorageKey {
            typealias Value = HTTPServer.Configuration
        }
    }
}
