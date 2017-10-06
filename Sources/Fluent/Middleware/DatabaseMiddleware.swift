import Async
import HTTP
import SQLite

/// This middleware stores the supplied Fluent database
/// on request workers. This database can then be fetched
/// from a given request for queries.
public final class DatabaseMiddleware: Middleware {
    /// This middleware's database.
    public let database: Database

    /// Create a new database middleware with the
    /// supplied database.
    public init(database: Database) {
        self.database = database
    }

    /// See Responder.respond(to:...)
    public func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        req.worker?.database = self.database
        let res = try next.respond(to: req)
        try req.releaseCurrentConnection()
        return res
    }
}
