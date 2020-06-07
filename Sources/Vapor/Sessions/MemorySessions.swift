/// Simple in-memory sessions implementation.
public struct MemorySessions: SessionDriver {
    internal let storage: Storage
    
    internal final class Storage {
        var sessions: [SessionID: SessionData]
        let queue: DispatchQueue
        init() {
            self.sessions = [:]
            self.queue = DispatchQueue(label: "MemorySessions.Storage")
        }
    }

    internal init(storage: Storage) {
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
    
    // Horribly unperformant. Avoid using.
    public func deleteExpiredSessions(
        before: Date,
        on request: Request
    ) -> EventLoopFuture<Void> {
        self.storage.queue.sync {
            self.storage.sessions.forEach { session in
                if session.1.expiration < before {
                    self.storage.sessions[session.0] = nil
                }
            }
        }
        return request.eventLoop.makeSucceededFuture(())
    }
    
    private func generateID() -> SessionID {
        var bytes = Data()
        for _ in 0..<32 {
            bytes.append(UInt8.random(in: UInt8.min..<UInt8.max))
        }
        return .init(string: bytes.base64EncodedString())
    }
}
