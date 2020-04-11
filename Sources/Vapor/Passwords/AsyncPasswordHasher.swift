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
    private let hasher: PasswordHasher
    private let threadPool: NIOThreadPool
    private let eventLoop: EventLoop
    
    public init(hasher: PasswordHasher, threadPool: NIOThreadPool, eventLoop: EventLoop) {
        self.hasher = hasher
        self.threadPool = threadPool
        self.eventLoop = eventLoop
    }
    
    public func hash<Password>(_ password: Password) -> EventLoopFuture<[UInt8]>
        where Password: DataProtocol
    {
        let promise = self.eventLoop.makePromise(of: [UInt8].self)
        self.threadPool.submit { _ in
            do {
                return promise.succeed(try self.hasher.hash(password))
            } catch  {
                return promise.fail(error)
            }
        }
        return promise.futureResult
    }
    
    public func verify<Password, Digest>(
        _ password: Password,
        created digest: Digest
    ) -> EventLoopFuture<Bool>
        where Password: DataProtocol, Digest: DataProtocol
    {
        let promise = eventLoop.makePromise(of: Bool.self)
        self.threadPool.submit { _ in
            do {
                return promise.succeed(try self.hasher.verify(password, created: digest))
            } catch {
                return promise.fail(error)
            }
        }
        return promise.futureResult
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
