import Foundation

extension Application {
    public var router: Router {
        .init(application: self)
    }

    public struct Router {
        public struct Provider {
            let run: (Application) -> ()
            
            public static var `default`: Self {
                .init {
                    $0.router.use { $0.router.default }
                }
            }

            public init(_ run: @escaping (Application) -> ()) {
                self.run = run
            }
        }

        final class Storage {
            var factory: ((Application) -> RouterFactory)?
            init() { }
        }

        struct Key: StorageKey {
            typealias Value = Storage
        }

        public let application: Application

        public var current: RouterFactory {
            guard let factory = self.storage.factory else {
                fatalError("No router configured. Configure with app.router.use(...)")
            }
            return factory(self.application)
        }

        public func use(_ provider: Provider) {
            provider.run(self.application)
        }
        
        public func use(_ factory: @escaping (Application) -> RouterFactory) {
            self.storage.factory = factory
        }
        
        public var `default`: RouterFactory { trie }

        var storage: Storage {
            guard let storage = self.application.storage[Key.self] else {
                fatalError("Router not configured. Configure with app.router.initialize()")
            }
            return storage
        }

        func initialize() {
            self.application.storage[Key.self] = .init()
        }
    }
}
