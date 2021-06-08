#if compiler(>=5.5)
import _NIOConcurrency

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension AsyncPasswordHasher {
    public func hash<Password>(_ password: Password) async throws -> [UInt8]
        where Password: DataProtocol
    {
        try await self.hash(password).get()
    }

    public func verify<Password, Digest>(
        _ password: Password,
        created digest: Digest
    ) async throws -> Bool
        where Password: DataProtocol, Digest: DataProtocol
    {
        try await self.verify(password, created: digest).get()
    }

    public func hash(_ password: String) async throws -> String {
        try await self.hash(password).get()
    }

    public func verify(_ password: String, created digest: String) async throws -> Bool {
        try await self.verify(password, created: digest).get()
    }
}

#endif
