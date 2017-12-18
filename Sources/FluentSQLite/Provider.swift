import Service
import SQLite

/// Registers and boots SQLite services.
public final class SQLiteProvider: Provider {
    /// See Provider.repositoryName
    public static let repositoryName = "fluent-sqlite"

    /// Create a new SQLite provider.
    public init() { }

    /// See Provider.register
    public func register(_ services: inout Services) throws {
        services.instance(SQLiteConfig())
        services.register(SQLiteDatabase.self) { container -> SQLiteDatabase in
            let storage = try container.make(SQLiteStorage.self, for: SQLiteProvider.self)
            return SQLiteDatabase(storage: storage)
        }
    }

    /// See Provider.boot
    public func boot(_ container: Container) throws {}
}
