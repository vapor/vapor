import NIOConcurrencyHelpers

extension Application {
    public var servers: Servers {
        .init(application: self)
    }

    /// The application's server.
    ///
    /// The instance is created once and reused. It has to be: the server holds the state tying a
    /// running server to anyone awaiting its ``Server/listeningAddress``, so handing out a fresh
    /// instance per access means `app.server.run()` and `app.server.listeningAddress` talk to
    /// different objects, and the waiter is never resumed.
    public var server: any Server {
        let storage = self.servers.storage
        if let existing = storage.makeServer.withLockedValue({ $0.cached }) {
            return existing
        }
        guard let makeServer = storage.makeServer.withLockedValue({ $0.factory }) else {
            fatalError("No server configured. Configure with app.servers.use(...)")
        }
        // Built outside the lock: a factory is free to touch application storage, which takes locks
        // of its own.
        let created = makeServer(self)
        return storage.makeServer.withLockedValue { state in
            // Another task may have built one while we were; if so, theirs wins so that everyone
            // shares a single instance.
            if let existing = state.cached {
                return existing
            }
            state.cached = created
            return created
        }
    }

    public struct Servers: Sendable {
        public struct Provider {
            let run: @Sendable (Application) -> ()

            public init(_ run: @Sendable @escaping (Application) -> ()) {
                self.run = run
            }
        }

        final class Storage: Sendable {
            struct ServerFactory {
                let factory: (@Sendable (Application) -> any Server)?
                /// The instance handed out by ``Application/server``, built on first use.
                var cached: (any Server)?
            }
            let makeServer: NIOLockedValueBox<ServerFactory>
            init() {
                self.makeServer = .init(.init(factory: nil, cached: nil))
            }
        }

        struct Key: StorageKey {
            typealias Value = Storage
        }

        func initialize() {
            self.application.storage[Key.self] = .init()
        }

        public func use(_ provider: Provider) {
            provider.run(self.application)
        }

        public func use(_ makeServer: @Sendable @escaping (Application) -> (any Server)) {
            // Drops any cached instance: the next `app.server` must come from the new factory.
            self.storage.makeServer.withLockedValue { $0 = .init(factory: makeServer, cached: nil) }
        }

        let application: Application

        var storage: Storage {
            guard let storage = self.application.storage[Key.self] else {
                fatalError("Servers not initialized. Configure with app.servers.initialize()")
            }
            return storage
        }
    }
}
