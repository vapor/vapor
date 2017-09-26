/// A `Driver` execute queries
/// and returns an array of results.
/// It is responsible for interfacing
/// with the data store powering Fluent.
public protocol Driver: Executor {
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
    var idKey: String { get }
    
    /// The default type for values stored against the identifier key.
    ///
    /// The `idType` will be accessed by those Entity implementations
    /// which do not themselves implement `Entity.idType`.
    var idType: IdentifierType { get }
    
    /// The naming convetion to use for foreign
    /// id keys, table names, etc.
    /// ex: snake_case vs. camelCase.
    var keyNamingConvention: KeyNamingConvention { get }
    
    // Object to log queries to
    var queryLogger: QueryLogger? { get set }

    /// Creates a connection for executing
    /// queries. This method is used to
    /// automatically create a connection
    /// if any Executor methods are called on
    /// the Driver.
    func makeConnection(_ type: ConnectionType) throws -> Connection
}

// MARK: Executor

extension Driver {
    /// See Executor protocol.
    @discardableResult
    public func query<E>(_ query: RawOr<Query<E>>) throws -> Node {
        let type: ConnectionType
        switch query {
        case .raw:
            type = .readWrite
        case .some(let q):
            type = q.connectionType
        }
        
        var connection = try makeConnection(type)
        connection.queryLogger = self.queryLogger
        return try connection.query(query)
    }
}
