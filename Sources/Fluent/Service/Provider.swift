import HTTP
import Service
import SQLite

public final class FluentProvider: Provider {
    public static var repositoryName: String = "fluent"

    public init() { }

    public func register(_ services: inout Services) throws {
        services.register(Database.self) { container -> SQLiteDatabase in
            let storage = try container.make(SQLiteStorage.self, for: SQLiteDatabase.self)
            return SQLiteDatabase(storage: storage)
        }

        services.register(Middleware.self) { container -> DatabaseMiddleware in
            let database = try container.make(Database.self, for: DatabaseMiddleware.self)
            return DatabaseMiddleware(database: database)
        }
    }

    public func boot(_ container: Container) throws {}
}
