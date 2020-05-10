/// Simple in-memory sessions implementation.
public struct MemorySessions: SessionDriver {
    public let storage: Storage
    
    public final class Storage {
        public var sessions: [SessionID: (SessionData, Date)]
        public let queue: DispatchQueue
        public init() {
            self.sessions = [:]
            self.queue = DispatchQueue(label: "MemorySessions.Storage")
        }
    }

    public init(storage: Storage) {
        self.storage = storage
    }

    public func createSession(
        _ data: SessionData,
        expiring: Date,
        for request: Request
    ) -> EventLoopFuture<SessionID> {
        let sessionID = self.generateID()
        self.storage.queue.sync {
            self.storage.sessions[sessionID] = (data, expiring)
        }
        return request.eventLoop.makeSucceededFuture(sessionID)
    }
    
    public func readSession(
        _ sessionID: SessionID,
        for request: Request
    ) -> EventLoopFuture<(SessionData, Date)?> {
        let session = self.storage.queue.sync { self.storage.sessions[sessionID] }
        return request.eventLoop.makeSucceededFuture(session)
    }
    
    public func updateSession(
        _ sessionID: SessionID,
        to data: SessionData?,
        expiring: Date?,
        for request: Request
    ) -> EventLoopFuture<SessionID> {
        var failed = false
        if data != nil || expiring != nil {
            self.storage.queue.sync {
                let temp = self.storage.sessions[sessionID]
                if var temp = temp {
                    if let data = data { temp.0 = data }
                    if let expiring = expiring { temp.1 = expiring }
                    self.storage.sessions[sessionID] = temp
                } else { failed = true }
            }
        }
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
                if session.value.1 < before {
                    self.storage.sessions[session.key] = nil
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
