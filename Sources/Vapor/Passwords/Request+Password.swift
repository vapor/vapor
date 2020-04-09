extension Request {
    public var password: Password {
        .init(request: self)
    }
    
    public struct Password: PasswordHasher {
        let request: Request
        
        public var async: AsyncPasswordHasher {
            self.request.application.password.sync.async(
                on: self.request.application.threadPool,
                hopTo: self.request.eventLoop
            )
        }
        
        public var sync: PasswordHasher {
            self.request.application.password.sync
        }
        
        public func verify<Password, Digest>(
            _ password: Password,
            created digest: Digest
        ) throws -> Bool
            where Password: DataProtocol, Digest: DataProtocol
        {
            try self.sync.verify(password, created: digest)
        }
        
        public func hash<Password>(_ password: Password) throws -> [UInt8]
            where Password: DataProtocol
        {
            try self.sync.hash(password)
        }
    }
}
