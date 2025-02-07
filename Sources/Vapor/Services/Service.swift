import NIOConcurrencyHelpers

extension Application {
    public struct Service<ServiceType> {

        let application: Application

        public init(application: Application) {
            self.application = application
        }

        public struct Provider {
            let run: (Application) -> Void

            public init(_ run: @escaping @Sendable (Application) -> Void) {
                self.run = run
            }
        }

        final class Storage: Sendable {
            let makeService: NIOLockedValueBox<(@Sendable (Application) -> ServiceType)?>
            init() {
                self.makeService = .init(nil)
            }
        }

        struct Key: StorageKey {
            typealias Value = Storage
        }

        public var service: ServiceType {
            guard let makeService = self.storage.makeService.withLockedValue({ $0 }) else {
                fatalError("No service configured for \(ServiceType.self)")
            }
            return makeService(self.application)
        }

        public func use(_ provider: Provider) {
            provider.run(self.application)
        }

        public func use(_ makeService: @escaping @Sendable (Application) -> ServiceType) {
            self.storage.makeService.withLockedValue { $0 = makeService }
        }

        func initialize() -> Storage {
            let new = Storage()
            self.application.storage[Key.self] = new
            return new
        }

        private var storage: Storage {
            if let storage = application.storage[Key.self] {
                return storage
            } else {
                return self.initialize()
            }
        }
    }
}
