import Foundation
import NIOPosix

extension Application {
    public var password: Password {
        .init(application: self)
    }

    public struct Password: PasswordHasher {
        let application: Application

        public var hasher: any PasswordHasher {
            guard let makeVerifier = self.application.passwords.storage.makeVerifier.withLockedValue({ $0.factory }) else {
                fatalError("No password verifier configured. Configure with app.passwords.use(...)")
            }
            return makeVerifier(self.application)
        }

        public func verify<Password, Digest>(
            _ password: Password,
            created digest: Digest
        ) async throws -> Bool
            where Password: DataProtocol, Digest: DataProtocol
        {
            try await self.hasher.verify(password, created: digest)
        }

        public func hash<Password>(_ password: Password) async throws -> [UInt8]
            where Password: DataProtocol
        {
            try await self.hasher.hash(password)
        }
    }
}
