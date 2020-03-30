extension Request {
    public var passwordVerifier: PasswordVerifier {
        self.application.passwordVerifiers.passwordVerifier.for(self)
    }
}

extension Application {
    public struct PasswordVerifiers {
        public struct Provider {
            public static var bcrypt: Self {
                .init {
                    $0.passwordVerifiers.use { $0.passwordVerifiers.bcrypt }
                }
            }

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

        var bcrypt: BCryptDigest {
            return .init()
        }

        public var passwordVerifier: PasswordVerifier {
            guard let makeVerifier = self.storage.makeVerifier else {
                fatalError("No password verifier configured. Configure with app.passwordVerifiers.use(...)")
            }
            return makeVerifier(self.application)
        }

        public func use(_ provider: Provider) {
            provider.run(self.application)
        }

        public func use(_ makeVerifier: @escaping (Application) -> (PasswordVerifier)) {
            self.storage.makeVerifier = makeVerifier
        }

        public func initialize() {
            self.application.storage[Key.self] = .init()
            // Default to BCrypt
            self.use(.bcrypt)
        }

        private var storage: Storage {
            guard let storage = self.application.storage[Key.self] else {
                fatalError("PasswordVerifiers not configured. Configure with app.passwordVerifiers.initialize()")
            }
            return storage
        }
    }
    
    public var passwordVerifiers: PasswordVerifiers {
        .init(application: self)
    }
}
