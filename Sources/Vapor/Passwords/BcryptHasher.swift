import Foundation
import NIOPosix

public struct BcryptHasher: PasswordHasher {
    let cost: Int

    public init(cost: Int = 12) {
        self.cost = cost
    }

    public func hash<Password>(
        _ password: Password
    ) async throws -> [UInt8]
        where Password: DataProtocol & Sendable
    {
        let string = String(decoding: password, as: UTF8.self)
        let digest = try await NIOThreadPool.singleton.runIfActive {
            try Bcrypt.hash(string, cost: self.cost)
        }
        return .init(digest.utf8)
    }

    public func verify<Password, Digest>(
        _ password: Password,
        created digest: Digest
    ) async throws -> Bool
        where Password: DataProtocol & Sendable, Digest: DataProtocol & Sendable
    {
        try await NIOThreadPool.singleton.runIfActive {
            try Bcrypt.verify(
                String(decoding: password.copyBytes(), as: UTF8.self),
                created: String(decoding: digest.copyBytes(), as: UTF8.self)
            )
        }
    }
}
