/// Simple in-memory sessions implementation.
public struct MemorySessions: Sessions {
    public let storage: Storage
    public let eventLoopGroup: EventLoopGroup
    
    public final class Storage {
        public var sessions: [SessionID: SessionData]
        public let queue: DispatchQueue
        public init() {
            self.sessions = [:]
            self.queue = DispatchQueue(label: "MemorySessions.Storage")
        }
    }

    /// Create a new `MemorySessions` with the supplied cookie factory.
    public init(storage: Storage, on eventLoopGroup: EventLoopGroup) {
        self.storage = storage
        self.eventLoopGroup = eventLoopGroup
    }

    public func createSession(_ data: SessionData) -> EventLoopFuture<SessionID> {
        let sessionID = self.generateID()
        self.storage.queue.sync {
            self.storage.sessions[sessionID] = data
        }
        return self.eventLoopGroup.next().makeSucceededFuture(sessionID)
    }
    
    public func readSession(_ sessionID: SessionID) -> EventLoopFuture<SessionData?> {
        let session = self.storage.queue.sync { self.storage.sessions[sessionID] }
        return self.eventLoopGroup.next().makeSucceededFuture(session)
    }
    
    public func updateSession(_ sessionID: SessionID, to data: SessionData) -> EventLoopFuture<SessionID> {
        self.storage.queue.sync { self.storage.sessions[sessionID] = data }
        return self.eventLoopGroup.next().makeSucceededFuture(sessionID)
    }
    
    public func deleteSession(_ sessionID: SessionID) -> EventLoopFuture<Void> {
        self.storage.queue.sync { self.storage.sessions[sessionID] = nil }
        return self.eventLoopGroup.next().makeSucceededFuture(())
    }
    
    private func generateID() -> SessionID {
        var bytes = Data()
        for _ in 0..<32 {
            bytes.append(UInt8.random(in: UInt8.min..<UInt8.max))
        }
        return .init(string: bytes.base64EncodedString())
    }
}
