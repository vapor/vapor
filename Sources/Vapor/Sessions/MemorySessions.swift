import Foundation
import NIOCore
import NIOConcurrencyHelpers

/// Simple in-memory sessions implementation.
public struct MemorySessions: SessionDriver, Sendable {
    public let storage: Storage
    
    public actor Storage {
        private var sessions: [SessionID: SessionData]
        public init() {
            self.sessions = [:]
        }

        public func get(_ sessionID: SessionID) -> SessionData? {
            self.sessions[sessionID]
        }

        public func set(_ sessionID: SessionID, to data: SessionData?) {
            self.sessions[sessionID] = data
        }
    }

    public init(storage: Storage) {
        self.storage = storage
    }

    public func createSession(
        _ data: SessionData,
        for request: Request
    ) async throws -> SessionID {
        let sessionID = self.generateID()
        await self.storage.set(sessionID, to: data)
        return sessionID
    }
    
    public func readSession(
        _ sessionID: SessionID,
        for request: Request
    ) async throws -> SessionData? {
        await self.storage.get(sessionID)
    }
    
    public func updateSession(
        _ sessionID: SessionID,
        to data: SessionData,
        for request: Request
    ) async throws -> SessionID {
        await self.storage.set(sessionID, to: data)
        return sessionID
    }
    
    public func deleteSession(
        _ sessionID: SessionID,
        for request: Request
    ) async throws {
        await self.storage.set(sessionID, to: nil)
    }
    
    private func generateID() -> SessionID {
        return .init(string: [UInt8].random(count: 32).base64String())
    }
}
