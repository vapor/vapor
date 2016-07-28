import Engine
import Fluent

extension Providable {
    /**
        Merges one Providable struct with another
        to accumulate the objects provided by 
        all Providers.
    */
    public func merged(with other: Providable) throws -> Providable {
        func attempt<T: Any>(_ existing: T?, _ new: T?) throws -> T? {
            if let new = new {
                if existing != nil {
                    throw ProvidableError.overwritten(T.self)
                }
                return new
            } else {
                return existing
            }
        }

        var server: Server.Type?
        var router: Router?
        var sessions: Sessions?
        var hash: Hash?
        var console: ConsoleProtocol?
        var log: Log?
        var client: Client.Type?
        var database: Database?

        server = try attempt(self.server, other.server)
        router = try attempt(self.router, other.router)
        sessions = try attempt(self.sessions, other.sessions)
        hash = try attempt(self.hash, other.hash)
        console = try attempt(self.console, other.console)
        log = try attempt(self.log, other.log)
        client = try attempt(self.client, other.client)
        database = try attempt(self.database, other.database)

        return Providable(
            server: server,
            router: router,
            sessions: sessions,
            hash: hash,
            console: console,
            log: log,
            client: client,
            database: database
        )
    }
}
