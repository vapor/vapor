import Foundation
import NIOCore
import NIOConcurrencyHelpers

/// Simple in-memory sessions implementation.
public struct AsyncMemorySessions: AsyncSessionDriver, Sendable {
    public let storage: Storage
    
    public actor Storage {
        private var sessions: [SessionID: SessionData]
        public init() {
            self.sessions = [:]
        }
        
        public func upsertSession(id: SessionID, data: SessionData) {
            self.sessions[id] = data
        }
        
        public func getSession(id: SessionID) -> SessionData? {
            self.sessions[id]
        }
        
        public func deleteSession(id: SessionID) {
            self.sessions[id] = nil
        }
    }

    public init(storage: Storage) {
        self.storage = storage
    }
    
    public func createSession(_ data: SessionData, for request: Request) async throws -> SessionID {
        let sessionID = self.generateID()
        await self.storage.upsertSession(id: sessionID, data: data)
        return sessionID
    }
    
    public func readSession(_ sessionID: SessionID, for request: Request) async throws -> SessionData? {
        await self.storage.getSession(id: sessionID)
    }
    
    public func updateSession(_ sessionID: SessionID, to data: SessionData, for request: Request) async throws -> SessionID {
        await self.storage.upsertSession(id: sessionID, data: data)
        return sessionID
    }
    
    public func deleteSession(_ sessionID: SessionID, for request: Request) async throws {
        await self.storage.deleteSession(id: sessionID)
    }
    
    private func generateID() -> SessionID {
        return .init(string: [UInt8].random(count: 32).base64String())
    }
}
