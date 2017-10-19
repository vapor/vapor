import Async
import HTTP
import SQLite

/// This middleware stores the supplied Fluent database
/// on request workers. This database can then be fetched
/// from a given request for queries.
public final class DatabaseMiddleware: Middleware {
    /// This middleware's database.
    public let database: Database

    /// The database's unique name.
    public let name: String

    /// Create a new database middleware with the
    /// supplied database.
    public init(database: Database, name: String = .defaultDatabaseName) {
        self.database = database
        self.name = name
    }

    /// See Responder.respond(to:...)
    public func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        try req.requireWorker().setDatabase(named: name, to: database)
        let res = try next.respond(to: req)
        try req.releaseCurrentConnection()
        return res
    }
}
