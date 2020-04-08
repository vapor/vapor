extension Application {
    public var passwords: Passwords {
        .init(application: self)
    }

    public struct Passwords {
        public struct Provider {
            let run: (Application) -> ()

            public init(_ run: @escaping (Application) -> ()) {
                self.run = run
            }
        }

        struct Key: StorageKey {
            typealias Value = Storage
        }

        let application: Application

        public func use(_ provider: Provider) {
            provider.run(self.application)
        }

        public func use(
            _ makeVerifier: @escaping (Application) -> (PasswordHasher)
        ) {
            self.storage.makeVerifier = makeVerifier
        }

        final class Storage {
            var makeVerifier: ((Application) -> PasswordHasher)?
            init() { }
        }

        var storage: Storage {
            if let existing = self.application.storage[Key.self] {
                return existing
            } else {
                let new = Storage()
                self.application.storage[Key.self] = new
                return new
            }
        }
    }
}
