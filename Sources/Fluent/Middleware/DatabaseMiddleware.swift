import Async
import HTTP
import SQLite

/// This middleware stores the supplied Fluent database
/// on request workers. This database can then be fetched
/// from a given request for queries.
public final class DatabaseMiddleware: Middleware {
    /// This middleware's database.
    public let databases: Databases

    /// Create a new database middleware with the
    /// supplied database.
    public init(databases: Databases) {
        self.databases = databases
    }

    /// See Responder.respond(to:...)
    public func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        let worker = try req.requireWorker()
        for (id, database) in databases.storage {
            worker.setDatabase(id: id, to: database)
        }
        let res = try next.respond(to: req)
        for id in databases.storage.keys {
            try req.releaseCurrentConnection(database: id)
        }
        return res
    }
}
