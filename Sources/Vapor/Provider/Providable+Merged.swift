import HTTP
import Fluent
import Console
import Cache

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
                    if
                        let e = existing as? [String: Middleware],
                        let n = new as? [String: Middleware]
                    {
                        var tmp = e

                        for (key, val) in n {
                            if tmp[key] != nil {
                                throw ProvidableError.overwritten(T.self)
                            }
                            
                            tmp[key] = val
                        }

                        return tmp as? T
                    }
                    throw ProvidableError.overwritten(T.self)
                }
                return new
            } else {
                return existing
            }
        }

        var server: ServerProtocol.Type?
        var hash: Hash?
        var console: ConsoleProtocol?
        var log: Log?
        var view: ViewRenderer?
        var client: ClientProtocol.Type?
        var database: Database?
        var cache: CacheProtocol?
        var middleware: [String: Middleware]?

        server = try attempt(self.server, other.server)
        hash = try attempt(self.hash, other.hash)
        console = try attempt(self.console, other.console)
        log = try attempt(self.log, other.log)
        view = try attempt(self.view, other.view)
        client = try attempt(self.client, other.client)
        database = try attempt(self.database, other.database)
        cache = try attempt(self.cache, other.cache)
        middleware = try attempt(self.middleware, other.middleware)

        return Providable(
            server: server,
            hash: hash,
            console: console,
            log: log,
            view: view,
            client: client,
            database: database,
            cache: cache,
            middleware: middleware
        )
    }
}
