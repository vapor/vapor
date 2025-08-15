import Foundation
import NIOPosix

extension Application.Passwords.Provider {
    public static var bcrypt: Self {
        .bcrypt(cost: 12)
    }
    
    public static func bcrypt(cost: Int) -> Self {
        .init {
            $0.passwords.use { _ in
                BcryptHasher(cost: cost)
            }
        }
    }
}

struct BcryptHasher: PasswordHasher {
    let cost: Int
    func hash<Password>(
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

    func verify<Password, Digest>(
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
