extension Request {
    public var passwords: PasswordService {
        self.application.passwords.passwords.for(self)
    }
}

extension Application {
    
    public struct Passwords {
        public struct Provider {
            public static var bcrypt: Self {
                .init {
                    $0.passwords.use { $0.passwords.bcrypt }
                }
            }

            let run: (Application) -> ()

            public init(_ run: @escaping (Application) -> ()) {
                self.run = run
            }
        }
        
        final class Storage {
            var makePasswordService: ((Application) -> PasswordService)?
            init() { }
        }

        struct Key: StorageKey {
            typealias Value = Storage
        }

        let application: Application

        var bcrypt: BCryptDigest {
            return .init()
        }

        public var passwords: PasswordService {
            guard let makeService = self.storage.makePasswordService else {
                fatalError("No password service configured. Configure with app.passwords.use(...)")
            }
            return makeService(self.application)
        }

        public func use(_ provider: Provider) {
            provider.run(self.application)
        }

        public func use(_ makePasswordService: @escaping (Application) -> (PasswordService)) {
            self.storage.makePasswordService = makePasswordService
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

    public var passwords: Passwords {
        .init(application: self)
    }
}

extension Application.Passwords: PasswordService {    
    public func hash(_ plaintext: String) throws -> String {
        try self.passwords.hash(plaintext)
    }
    
    public func verify<Password, Digest>(_ password: Password, created digest: Digest) throws -> Bool where Password : DataProtocol, Digest : DataProtocol {
        try self.passwords.verify(password, created: digest)
    }
    
    public func `for`(_ request: Request) -> PasswordService {
        self.passwords
    }
}
