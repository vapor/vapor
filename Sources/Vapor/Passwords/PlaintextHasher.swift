import Foundation

extension Application.Passwords.Provider {
    public static var plaintext: Self {
        .init {
            $0.passwords.use { _ in
                PlaintextHasher()
            }
        }
    }
}

private struct PlaintextHasher: PasswordHasher {
    func hash<Password>(_ password: Password) async throws -> [UInt8]
        where Password: DataProtocol
    {
        password.copyBytes()
    }

    func verify<Password, Digest>(
        _ password: Password,
        created digest: Digest
    ) async throws -> Bool
        where Password: DataProtocol, Digest: DataProtocol
    {
        password.copyBytes() == digest.copyBytes()
    }
}
