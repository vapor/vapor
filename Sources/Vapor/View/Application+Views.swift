extension Application {
    public var views: Views {
        .init(application: self)
    }

    public var view: ViewRenderer {
        guard let makeRenderer = self.views.storage.makeRenderer else {
            fatalError("No renderer configured. Configure with app.views.use(...)")
        }
        return makeRenderer(self)
    }

    public struct Views: Sendable {
        public struct Provider: Sendable {
            public static var plaintext: Self {
                .init {
                    $0.views.use { $0.views.plaintext }
                }
            }

            let run: @Sendable (Application) -> ()

            public init(_ run: @Sendable @escaping (Application) -> ()) {
                self.run = run
            }
        }
        
        // This doesn't need a lock as it's only mutated during app configuration
        final class Storage {
            var makeRenderer: (@Sendable (Application) -> ViewRenderer)?
            init() { }
        }

        struct Key: StorageKey, Sendable {
            typealias Value = Storage
        }

        let application: Application

        public var plaintext: PlaintextRenderer {
            return .init(
                fileio: self.application.fileio,
                viewsDirectory: self.application.directory.viewsDirectory,
                logger: self.application.logger,
                eventLoopGroup: self.application.eventLoopGroup
            )
        }

        public func use(_ provider: Provider) {
            provider.run(self.application)
        }

        public func use(_ makeRenderer: @Sendable @escaping (Application) -> (ViewRenderer)) {
            self.storage.makeRenderer = makeRenderer
        }

        func initialize() {
            self.application.storage[Key.self] = .init()
            self.use(.plaintext)
        }

        var storage: Storage {
            guard let storage = self.application.storage[Key.self] else {
                fatalError("Views not configured. Configure with app.views.initialize()")
            }
            return storage
        }
    }
}
