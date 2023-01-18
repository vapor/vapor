/// Simple in-memory sessions implementation.
public struct MemorySessions: SessionDriver {
    public let storage: Storage
    
    public final class Storage {
        public var sessions: [SessionID: SessionData]
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
