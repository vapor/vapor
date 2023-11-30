import NIOCore
import NIOConcurrencyHelpers

extension Application {
    public var responder: Responder {
        .init(application: self)
    }

    public struct Responder {
        public struct Provider: Sendable {
            public static var `default`: Self {
                .init {
                    $0.responder.use { $0.responder.asyncDefault }
                }
            }

            let run: @Sendable (Application) -> ()

            @preconcurrency public init(_ run: @Sendable @escaping (Application) -> ()) {
                self.run = run
            }
        }

        final class Storage: Sendable {
            struct ResponderFactory {
                let factory: (@Sendable (Application) -> Vapor.AsyncResponder)?
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

        @available(*, deprecated, message: "Use asyncCurrent instead")
        public var current: Vapor.Responder {
            guard let factory = self.storage.factory.withLockedValue({ $0.factory }) else {
                fatalError("No responder configured. Configure with app.responder.use(...)")
            }
            return factory(self.application)
        }
        
        public var asyncCurrent: Vapor.AsyncResponder {
            guard let factory = self.storage.factory.withLockedValue({ $0.factory }) else {
                fatalError("No responder configured. Configure with app.responder.use(...)")
            }
            return factory(self.application)
        }

        @available(*, deprecated, message: "Use asyncDefault instead")
        public var `default`: Vapor.Responder {
            DefaultResponder(
                routes: self.application.routes,
                middleware: self.application.middleware.asyncResolve(),
                reportMetrics: self.application.http.server.configuration.reportMetrics
            )
        }
        
        public var `asyncDefault`: Vapor.AsyncResponder {
            DefaultResponder(
                routes: self.application.routes,
                middleware: self.application.middleware.asyncResolve(),
                reportMetrics: self.application.http.server.configuration.reportMetrics
            )
        }

        public func use(_ provider: Provider) {
            provider.run(self.application)
        }

        @available(*, deprecated, message: "Provide an AsyncResponder instead")
        @preconcurrency public func use(_ factory: @Sendable @escaping (Application) -> (Vapor.Responder)) {
            #warning("Fix")
//            self.storage.factory.withLockedValue { $0 = .init(factory: factory) }
        }
        
        @preconcurrency public func use(_ factory: @Sendable @escaping (Application) -> (Vapor.AsyncResponder)) {
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

extension Application.Responder: AsyncResponder {
    public func respond(to request: Request) async throws -> Response {
        try await self.asyncCurrent.respond(to: request)
    }
}
