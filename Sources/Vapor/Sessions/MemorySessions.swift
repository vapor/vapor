#if os(Linux) && compiler(<6.0)
@preconcurrency import Foundation
#else
import Foundation
#endif
import NIOCore
import NIOConcurrencyHelpers

/// Simple in-memory sessions implementation.
public struct MemorySessions: SessionDriver, Sendable {
    public let storage: Storage
    
    public final class Storage: Sendable {
        public var sessions: [SessionID: SessionData] {
            get {
                self._sessions.withLockedValue { $0 }
            }
            set {
                self._sessions.withLockedValue { $0 = newValue }
            }
        }
        
        public let queue: DispatchQueue
        private let _sessions: NIOLockedValueBox<[SessionID: SessionData]>
        public init() {
            self._sessions = .init([:])
            self.queue = DispatchQueue(label: "MemorySessions.Storage")
        }
    }

    public init(storage: Storage) {
        self.storage = storage
    }

    public func createSession(
        _ data: SessionData,
        for request: Request
    ) -> EventLoopFuture<SessionID> {
        let sessionID = self.generateID()
        self.storage.queue.sync {
            self.storage.sessions[sessionID] = data
        }
        return request.eventLoop.makeSucceededFuture(sessionID)
    }
    
    public func readSession(
        _ sessionID: SessionID,
        for request: Request
    ) -> EventLoopFuture<SessionData?> {
        let session = self.storage.queue.sync { self.storage.sessions[sessionID] }
        return request.eventLoop.makeSucceededFuture(session)
    }
    
    public func updateSession(
        _ sessionID: SessionID,
        to data: SessionData,
        for request: Request
    ) -> EventLoopFuture<SessionID> {
        self.storage.queue.sync { self.storage.sessions[sessionID] = data }
        return request.eventLoop.makeSucceededFuture(sessionID)
    }
    
    public func deleteSession(
        _ sessionID: SessionID,
        for request: Request
    ) -> EventLoopFuture<Void> {
        self.storage.queue.sync { self.storage.sessions[sessionID] = nil }
        return request.eventLoop.makeSucceededFuture(())
    }
    
    private func generateID() -> SessionID {
        return .init(string: [UInt8].random(count: 32).base64String())
    }
}
