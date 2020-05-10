/// Capable of managing CRUD operations for `Session`s.
public protocol SessionDriver {
    func createSession(
        _ data: SessionData,
        expiring: Date,
        for request: Request
    ) -> EventLoopFuture<SessionID>
    
    func readSession(
        _ sessionID: SessionID,
        for request: Request
    ) -> EventLoopFuture<(SessionData, Date)?>
    
    func updateSession(
        _ sessionID: SessionID,
        to data: SessionData?,
        expiring: Date?,
        for request: Request
    ) -> EventLoopFuture<SessionID>
    
    func deleteSession(
        _ sessionID: SessionID,
        for request: Request
    ) -> EventLoopFuture<Void>
    
    func deleteExpiredSessions(
        before: Date,
        on request: Request
    ) -> EventLoopFuture<Void>
}
