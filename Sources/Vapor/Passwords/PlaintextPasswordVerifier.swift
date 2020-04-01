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
        
        final class Storage {
            var makeVerifier: ((Application) -> PasswordVerifier)?
            init() { }
        }

        struct Key: StorageKey {
            typealias Value = Storage
        }

        let application: Application

        public func use(_ provider: Provider) {
            provider.run(self.application)
        }

        public func use(_ makeVerifier: @escaping (Application) -> (PasswordVerifier)) {
            self.storage.makeVerifier = makeVerifier
        }

        func initialize() {
            self.application.storage[Key.self] = .init()
            // Default to BCrypt
            self.use(.bcrypt)
        }

        var storage: Storage {
            guard let storage = self.application.storage[Key.self] else {
                fatalError("PasswordHashers not configured. Configure with app.passwordHashers.initialize()")
            }
            return storage
        }
    }

    public var password: PasswordVerifier {
        guard let makeVerifier = self.passwords.storage.makeVerifier else {
            fatalError("No password verifier configured. Configure with app.passwords.use(...)")
        }
        return makeVerifier(self)
    }
}
