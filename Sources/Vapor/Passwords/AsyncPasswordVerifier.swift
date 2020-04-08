public struct AsyncPasswordVerifier {
    private let verifier: PasswordVerifier
    private let threadPool: NIOThreadPool
    private let eventLoop: EventLoop
    
    public init(verifier: PasswordVerifier, threadPool: NIOThreadPool, eventLoop: EventLoop) {
        self.verifier = verifier
        self.threadPool = threadPool
        self.eventLoop = eventLoop
    }
    
    public func digest<Password>(_ password: Password) throws -> EventLoopFuture<[UInt8]>
        where Password: DataProtocol
    {
        let promise = eventLoop.makePromise(of: [UInt8].self)
        self.threadPool.submit { _ in
            do {
                return promise.succeed(try self.verifier.digest(password))
            } catch  {
                return promise.fail(error)
            }
        }
        return promise.futureResult
    }
    
    public func verify<Password, Digest>(
        _ password: Password,
        created digest: Digest
    ) throws -> EventLoopFuture<Bool>
        where Password: DataProtocol, Digest: DataProtocol
    {
        let promise = eventLoop.makePromise(of: Bool.self)
        self.threadPool.submit { _ in
            do {
                return promise.succeed(try self.verifier.verify(password, created: digest))
            } catch {
                return promise.fail(error)
            }
        }
        return promise.futureResult
    }
    
    public func digest(_ password: String) throws -> EventLoopFuture<String> {
        try self.digest([UInt8](password.utf8)).map {
            String(decoding: $0, as: UTF8.self)
        }
    }

    public func verify(_ password: String, created digest: String) throws -> EventLoopFuture<Bool> {
        try self.verify(
            [UInt8](password.utf8),
            created: [UInt8](digest.utf8)
        )
    }
}
