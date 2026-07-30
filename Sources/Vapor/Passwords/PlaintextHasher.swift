#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct PlaintextHasher: PasswordHasher {
    public init() {}

    public func hash<Password>(_ password: Password) async throws -> [UInt8]
        where Password: DataProtocol
    {
        password.copyBytes()
    }

    public func verify<Password, Digest>(
        _ password: Password,
        created digest: Digest
    ) async throws -> Bool
        where Password: DataProtocol, Digest: DataProtocol
    {
        password.copyBytes() == digest.copyBytes()
    }
}
