extension Application.Servers.Provider {
    public static var http: Self {
        .init {
            $0.servers.use { $0.http.server.shared }
        }
    }
}

extension Application.HTTP {
    public var server: Server {
        .init(application: self.application)
    }
    
    public struct Server: Sendable {
        let application: Application

        public var shared: HTTPServer {
            if let existing = self.application.storage[Key.self] {
                return existing
            } else {
                let new = HTTPServer.init(
                    application: self.application,
                    responder: self.application.responder.asyncCurrent,
                    configuration: self.configuration,
                    on: self.application.eventLoopGroup
                )
                self.application.storage[Key.self] = new
                return new
            }
        }

        struct Key: StorageKey, Sendable {
            typealias Value = HTTPServer
        }

        public var configuration: HTTPServer.Configuration {
            get {
                self.application.storage[ConfigurationKey.self] ?? .init(
                    logger: self.application.logger
                )
            }
            nonmutating set {
                if self.application.storage.contains(Key.self) {
                    self.application.logger.warning("Cannot modify server configuration after server has been used.")
                } else {
                    self.application.storage[ConfigurationKey.self] = newValue
                }
            }
        }

        struct ConfigurationKey: StorageKey, Sendable {
            typealias Value = HTTPServer.Configuration
        }
    }
}
