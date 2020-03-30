extension Request {
    public var passwordHasher: PasswordHasher {
        self.application.passwordHashers.passwordHasher.for(self)
    }
}

extension Application {
    
    public struct PasswordHashers {
        public struct Provider {
            public static var bcrypt: Self {
                .init {
                    $0.passwordHashers.use { $0.passwordHashers.bcrypt }
                }
            }

            let run: (Application) -> ()

            public init(_ run: @escaping (Application) -> ()) {
                self.run = run
            }
        }
        
        final class Storage {
            var makeHasher: ((Application) -> PasswordHasher)?
            init() { }
        }

        struct Key: StorageKey {
            typealias Value = Storage
        }

        let application: Application

        var bcrypt: BCryptDigest {
            return .init()
        }

        public var passwordHasher: PasswordHasher {
            guard let makeHasher = self.storage.makeHasher else {
                fatalError("No password hasher configured. Configure with app.passwordHashers.use(...)")
            }
            return makeHasher(self.application)
        }

        public func use(_ provider: Provider) {
            provider.run(self.application)
        }

        public func use(_ makeHasher: @escaping (Application) -> (PasswordHasher)) {
            self.storage.makeHasher = makeHasher
        }

        public func initialize() {
            self.application.storage[Key.self] = .init()
            // Default to BCrypt
            self.use(.bcrypt)
        }

        private var storage: Storage {
            guard let storage = self.application.storage[Key.self] else {
                fatalError("PasswordHashers not configured. Configure with app.passwordHashers.initialize()")
            }
            return storage
        }
    }

    public var passwordHashers: PasswordHashers {
        .init(application: self)
    }
}
