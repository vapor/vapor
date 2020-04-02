extension Request {
    public var password: Password {
        Password(for: self)
    }
    
    public struct Password: PasswordVerifier {
        private let application: Application
        private let eventLoop: EventLoop
        
        init(for req: Request) {
            self.application = req.application
            self.eventLoop = req.eventLoop
        }
        
        public var async: AsyncPasswordVerifier {
            self.application.password.asynchronized(on: application.threadPool, hopTo: eventLoop)
        }
        
        public var verifier: PasswordVerifier {
            self.application.password
        }
        
        public func verify<Password, Digest>(_ password: Password, created digest: Digest) throws -> Bool where Password : DataProtocol, Digest : DataProtocol {
            try verifier.verify(password, created: digest)
        }
        
        public func digest<Password>(_ password: Password) throws -> [UInt8] where Password : DataProtocol {
            try verifier.digest(password)
        }
    }
}
