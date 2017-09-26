/// References a database with a single `Driver`.
/// Statically maps `Model`s to `Database`s.
public final class Database: Executor, QueryLogger {
    /// Maps `Model` names to their respective
    /// `Database`. This allows multiple models
    /// in the same application to use different
    /// methods of data persistence.
    public static var map: [String: Database] = [:]

    /// The default database for all `Model` types.
    public static var `default`: Database?

    /// The `Driver` powering this database.
    /// Responsible for executing queries.
    public let driver: Driver
    
    /// Maintains a pool of connections
    /// one for each thread
    public let threadConnectionPool: ThreadConnectionPool

    /// The string value for the
    /// default identifier key.
    ///
    /// The `idKey` will be used when
    /// `Model.find(_:)` or other find
    /// by identifier methods are used.
    ///
    /// This value is overriden by
    /// entities that implement the
    /// `Entity.idKey` static property.
    public var idKey: String

    /// The default type for values stored against the identifier key.
    ///
    /// The `idType` will be accessed by those Entity implementations
    /// which do not themselves implement `Entity.idType`.
    public var idType: IdentifierType

    /// The naming convetion to use for foreign
    /// id keys, table names, etc.
    /// ex: snake_case vs. camelCase.
    public var keyNamingConvention: KeyNamingConvention

    /// Creates a `Database` with the supplied
    /// `Driver`. This cannot be changed later.
    public init(_ driver: Driver, maxConnections: Int = 128) {
        idKey = driver.idKey
        idType = driver.idType
        keyNamingConvention = driver.keyNamingConvention

        threadConnectionPool = ThreadConnectionPool(
            driver,
            maxConnections: maxConnections // some number larger than the max threads
        )
        
        var driver = driver
        self.driver = driver
        driver.queryLogger = self
    }
    
    // MARK: Log
    
    /// A closure for handling database logs
    public typealias QueryLogCallback = (QueryLog) -> ()
    
    /// All queries performed by the database will be
    /// sent here right before they are run.
    public var log: QueryLogCallback?
    
    /// QueryLogger protocol
    public func log(_ statement: String, _ values: [Node]) {
        log?(QueryLog(statement, values))
    }
}

// MARK: Executor

extension Database {
    /// The database is the query logger, not settable
    public var queryLogger: QueryLogger? {
        get { return self }
        set { }
    }
    
    /// See Executor protocol.
    @discardableResult
    public func query<E>(_ query: RawOr<Query<E>>) throws -> Node {
        return try threadConnectionPool.query(query)
    }
}

