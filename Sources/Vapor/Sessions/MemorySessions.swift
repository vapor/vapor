import Bits
import Crypto

/// Simple in-memory sessions implementation.
public final class MemorySessions: Sessions {
    /// The internal storage.
    private var sessions: [String: Session]

    /// This session's event loop.
    private let eventLoop: EventLoop

    /// MemorySession with basic cookie factory.
    public static func `default`(on worker: Worker) -> MemorySessions {
        return .init(on: worker)
    }

    /// Create a new `MemorySessions` with the supplied cookie factory.
    public init(on worker: Worker) {
        self.eventLoop = worker.eventLoop
        sessions = [:]
    }

    /// See Sessions.readSession
    public func readSession(sessionID: String) throws -> Future<Session?> {
        let session = sessions[sessionID]
        return Future.map(on: eventLoop) { session }
    }

    /// See Sessions.destroySession
    public func destroySession(sessionID: String) throws -> Future<Void> {
        sessions[sessionID] = nil
        return .done(on: eventLoop)
    }

    /// See Sessions.updateSession
    public func updateSession(_ session: Session) throws -> Future<Session> {
        let sessionID: String
        if let existing = session.id {
            sessionID = existing
        } else {
            sessionID = try URandom().data(count: 16).base64Encoded()! // should never fail
        }
        session.id = sessionID
        sessions[sessionID] = session
        return Future.map(on: eventLoop) { session }
    }
}

extension MemorySessions: ServiceType {
    /// See `ServiceType.serviceSupports`
    public static var serviceSupports: [Any.Type] { return [Sessions.self] }

    /// See `ServiceType.makeService(for:)`
    public static func makeService(for worker: Container) throws -> MemorySessions {
        return .default(on: worker)
    }
}
