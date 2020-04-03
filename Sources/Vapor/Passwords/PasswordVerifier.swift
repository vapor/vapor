public protocol PasswordVerifier {
    func digest<Password>(_ password: Password) throws -> [UInt8]
        where Password: DataProtocol

    func verify<Password, Digest>(
        _ password: Password,
        created digest: Digest
    ) throws -> Bool
        where Password: DataProtocol, Digest: DataProtocol
}

extension PasswordVerifier {
    public func digest(_ password: String) throws -> String {
        try String(decoding: self.digest([UInt8](password.utf8)), as: UTF8.self)
    }

    public func verify(_ password: String, created digest: String) throws -> Bool {
        try self.verify(
            [UInt8](password.utf8),
            created: [UInt8](digest.utf8)
        )
    }
    
    public func async(on threadPool: NIOThreadPool, hopTo eventLoop: EventLoop) -> AsyncPasswordVerifier
     {
        AsyncPasswordVerifier(verifier: self, threadPool: threadPool, eventLoop: eventLoop)
    }
}
