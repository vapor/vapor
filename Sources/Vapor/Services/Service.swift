import NIOConcurrencyHelpers

extension Application {
    public struct Service<ServiceType> {

        let application: Application

        public init(application: Application) {
            self.application = application
        }

        public struct Provider {
            let run: (Application) -> ()

            public init(_ run: @escaping @Sendable (Application) -> ()) {
                self.run = run
            }
        }

        // We can make this unchecked as we're only storing a sendable closure and mutation is protected by the lock
        final class Storage: @unchecked Sendable {
            // At first glance, one could think that using a
            // `NIOLockedValueBox<(@Sendable (Application) -> ServiceType)?>` for `makeService` would be sufficient
            // here. However, for some reason, caling `self.storage.makeService.withLockedValue({ $0 })` repeatedly in
            // `Service.service` causes each subsequent call to the function stored inside the locked value to perform
            // one (or several) more "trampoline" function calls, slowing down the execution and eventually leading to a
            // stack overflow. This is why we use a `NIOLock` here instead; it seems to avoid the `{ $0 }` issue above
            // despite still accessing `_makeService` from within a closure (`{ self._makeService }`).
            let lock = NIOLock()

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
