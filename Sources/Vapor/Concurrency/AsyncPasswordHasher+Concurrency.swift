import Foundation
import NIOCore

extension AsyncPasswordHasher {
    public func hash<Password>(_ password: Password) async throws -> [UInt8]
    where Password: DataProtocol & Sendable {
        try await self.hash(password).get()
    }

    public func verify<Password, Digest>(
        _ password: Password,
        created digest: Digest
    ) async throws -> Bool
    where Password: DataProtocol & Sendable, Digest: DataProtocol & Sendable {
        try await self.verify(password, created: digest).get()
    }

    public func hash(_ password: String) async throws -> String {
        try await self.hash(password).get()
    }

    public func verify(_ password: String, created digest: String) async throws -> Bool {
        try await self.verify(password, created: digest).get()
    }
}
