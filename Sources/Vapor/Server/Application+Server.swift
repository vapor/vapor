extension Application {
    public var server: Server {
        .init(application: self)
    }

    public struct Server {
        let application: Application

        struct ConfigurationKey: StorageKey {
            typealias Value = HTTPServer.Configuration
        }

        public var configuration: HTTPServer.Configuration {
            get {
                self.application.storage[ConfigurationKey.self] ?? .init()
            }
            nonmutating set {
                self.application.storage[ConfigurationKey.self] = newValue
            }
        }

        public struct Running {
            let server: HTTPServer
            public func shutdown() {
                self.server.shutdown()
            }
        }

        struct CommandKey: StorageKey {
            typealias Value = ServeCommand
        }

        public var command: ServeCommand {
            if let existing = self.application.storage.get(CommandKey.self) {
                return existing
            } else {
                let new = ServeCommand()
                self.application.storage.set(CommandKey.self, to: new) {
                    $0.shutdown()
                }
                return new
            }
        }

        public func start(hostname: String? = nil, port: Int? = nil) throws -> Running {
            var configuration = self.configuration
            // determine which hostname / port to bind to
            configuration.hostname = hostname ?? self.configuration.hostname
            configuration.port = port ?? self.configuration.port
            let server = HTTPServer(
                application: self.application,
                responder: self.application.responder.current,
                configuration: configuration,
                on: self.application.eventLoopGroup
            )
            try server.start()
            return Running(server: server)
        }
    }
}
