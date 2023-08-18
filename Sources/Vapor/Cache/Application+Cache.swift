import NIOConcurrencyHelpers

extension Application {
    /// Controls application's configured caches.
    ///
    ///     app.caches.use(.memory)
    ///
    public var caches: Caches {
        .init(application: self)
    }

    /// Current application cache. See `Request.cache` for caching in request handlers.
    public var cache: Cache {
        guard let makeCache = self.caches.storage.makeCache.withLockedValue({ $0 }) else {
            fatalError("No cache configured. Configure with app.caches.use(...)")
        }
        return makeCache(self)
    }

    public struct Caches: Sendable {
        public struct Provider {
            let run: (Application) -> ()

            public init(_ run: @escaping (Application) -> ()) {
                self.run = run
            }
        }
        
        final class Storage: Sendable {
            let makeCache: NIOLockedValueBox<(@Sendable (Application) -> Cache)?>
            init() {
                self.makeCache = .init(nil)
            }
        }

        struct Key: StorageKey, Sendable {
            typealias Value = Storage
        }

        public let application: Application

        public func use(_ provider: Provider) {
            provider.run(self.application)
        }

        public func use(_ makeCache: @Sendable @escaping (Application) -> (Cache)) {
            self.storage.makeCache.withLockedValue { $0 =  makeCache }
        }

        func initialize() {
            self.application.storage[Key.self] = .init()
            self.use(.memory)
        }

        var storage: Storage {
            guard let storage = self.application.storage[Key.self] else {
                fatalError("Caches not configured. Configure with app.caches.initialize()")
            }
            return storage
        }
    }
}
