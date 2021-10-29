extension PasswordHasher {
    public func async(
        on threadPool: NIOThreadPool,
        hopTo eventLoop: EventLoop
    ) -> AsyncPasswordHasher {
        .init(
            hasher: self,
            threadPool: threadPool,
            eventLoop: eventLoop
        )
    }
}

public struct AsyncPasswordHasher {
    let hasher: PasswordHasher
    let threadPool: NIOThreadPool
    let eventLoop: EventLoop
    
    public init(hasher: PasswordHasher, threadPool: NIOThreadPool, eventLoop: EventLoop) {
        self.hasher = hasher
        self.threadPool = threadPool
        self.eventLoop = eventLoop
    }
    
    public func hash<Password>(_ password: Password) -> EventLoopFuture<[UInt8]>
        where Password: DataProtocol
    {
        return self.threadPool.runIfActive(eventLoop: self.eventLoop) {
            try self.hasher.hash(password)
        }
    }
    
    public func verify<Password, Digest>(
        _ password: Password,
        created digest: Digest
    ) -> EventLoopFuture<Bool>
        where Password: DataProtocol, Digest: DataProtocol
    {
        return self.threadPool.runIfActive(eventLoop: self.eventLoop) {
            try self.hasher.verify(password, created: digest)
        }
    }
    
    public func hash(_ password: String) -> EventLoopFuture<String> {
        self.hash([UInt8](password.utf8)).map {
            String(decoding: $0, as: UTF8.self)
        }
    }

    public func verify(_ password: String, created digest: String) -> EventLoopFuture<Bool> {
        self.verify(
            [UInt8](password.utf8),
            created: [UInt8](digest.utf8)
        )
    }
}
