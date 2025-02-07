import NIOCore

/// Capable of managing CRUD operations for `Session`s.
///
/// This is an async version of `SessionDriver`
public protocol AsyncSessionDriver: SessionDriver {
    func createSession(_ data: SessionData, for request: Request) async throws -> SessionID
    func readSession(_ sessionID: SessionID, for request: Request) async throws -> SessionData?
    func updateSession(_ sessionID: SessionID, to data: SessionData, for request: Request) async throws -> SessionID
    func deleteSession(_ sessionID: SessionID, for request: Request) async throws
}

extension AsyncSessionDriver {
    public func createSession(_ data: SessionData, for request: Request) -> EventLoopFuture<SessionID> {
        let promise = request.eventLoop.makePromise(of: SessionID.self)
        promise.completeWithTask {
            try await self.createSession(data, for: request)
        }
        return promise.futureResult
    }

    public func readSession(_ sessionID: SessionID, for request: Request) -> EventLoopFuture<SessionData?> {
        let promise = request.eventLoop.makePromise(of: SessionData?.self)
        promise.completeWithTask {
            try await self.readSession(sessionID, for: request)
        }
        return promise.futureResult
    }

    public func updateSession(_ sessionID: SessionID, to data: SessionData, for request: Request) -> EventLoopFuture<SessionID> {
        let promise = request.eventLoop.makePromise(of: SessionID.self)
        promise.completeWithTask {
            try await self.updateSession(sessionID, to: data, for: request)
        }
        return promise.futureResult
    }

    public func deleteSession(_ sessionID: SessionID, for request: Request) -> EventLoopFuture<Void> {
        let promise = request.eventLoop.makePromise(of: Void.self)
        promise.completeWithTask {
            try await self.deleteSession(sessionID, for: request)
        }
        return promise.futureResult
    }
}
