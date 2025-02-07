import NIOConcurrencyHelpers
import NIOCore

extension Application {
    public var responder: Responder {
        .init(application: self)
    }

    public struct Responder {
        public struct Provider: Sendable {
            public static var `default`: Self {
                .init {
                    $0.responder.use { $0.responder.default }
                }
            }

            let run: @Sendable (Application) -> Void

            @preconcurrency public init(_ run: @Sendable @escaping (Application) -> Void) {
                self.run = run
            }
        }

        final class Storage: Sendable {
            struct ResponderFactory {
                let factory: (@Sendable (Application) -> Vapor.Responder)?
            }
            let factory: NIOLockedValueBox<ResponderFactory>
            init() {
                self.factory = .init(.init(factory: nil))
            }
        }

        struct Key: StorageKey, Sendable {
            typealias Value = Storage
        }

        public let application: Application

        public var current: Vapor.Responder {
            guard let factory = self.storage.factory.withLockedValue({ $0.factory }) else {
                fatalError("No responder configured. Configure with app.responder.use(...)")
            }
            return factory(self.application)
        }

        public var `default`: Vapor.Responder {
            DefaultResponder(
                routes: self.application.routes,
                middleware: self.application.middleware.resolve(),
                reportMetrics: self.application.http.server.configuration.reportMetrics
            )
        }

        public func use(_ provider: Provider) {
            provider.run(self.application)
        }

        @preconcurrency public func use(_ factory: @Sendable @escaping (Application) -> (Vapor.Responder)) {
            self.storage.factory.withLockedValue { $0 = .init(factory: factory) }
        }

        var storage: Storage {
            guard let storage = self.application.storage[Key.self] else {
                fatalError("Responder not configured. Configure with app.responder.initialize()")
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
