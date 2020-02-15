extension Application {
    public var responder: Responder {
        .init(application: self)
    }

    public struct Responder {
        public struct Provider {
            public static var `default`: Self {
                .init {
                    $0.responder.use { $0.responder.default }
                }
            }

            let run: (Application) -> ()

            public init(_ run: @escaping (Application) -> ()) {
                self.run = run
            }
        }

        final class Storage {
            var factory: ((Application) -> Vapor.Responder)?
            init() { }
        }

        struct Key: StorageKey {
            typealias Value = Storage
        }

        let application: Application

        public var current: Vapor.Responder {
            guard let factory = self.storage.factory else {
                fatalError("No responder configured. Configure with app.responder.use(...)")
            }
            return factory(self.application)
        }

        public var `default`: Vapor.Responder {
            DefaultResponder(
                routes: self.application.routes,
                middleware: self.application.middleware.resolve()
            )
        }

        public func use(_ provider: Provider) {
            provider.run(self.application)
        }

        public func use(_ factory: @escaping (Application) -> (Vapor.Responder)) {
            self.storage.factory = factory
        }

        var storage: Storage {
            guard let storage = self.application.storage[Key.self] else {
                fatalError("Sessions not configured. Configure with app.sessions.initialize()")
            }
            return storage
        }

        func initialize() {
            self.application.storage[Key.self] = .init()
        }
    }
}

extension Application.Responder: Responder {
    public func respond(to request: Request) -> EventLoopFuture<Response> {
        self.current.respond(to: request)
    }
}
