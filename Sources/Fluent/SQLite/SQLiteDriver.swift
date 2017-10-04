import Random
import SQLite


/// An in memory driver that can be used for debugging and testing
/// built on top of SQLiteDriver
public final class MemoryDriver: SQLiteDriverProtocol {
    public let database: SQLiteDatabase
    public var queryLogger: QueryLogger?

    public init() throws {
        database = SQLiteDatabase(storage: .memory)
        try enableForeignKeys()
    }
}

/// Driver for using the SQLite database with Vapor
/// For debugging, we provide an in memory version of this driver
/// at MemoryDriver
///
/// Because SQLite is not a distributed and easily scaled database,
/// we do not recommend using it in Production
public final class SQLiteDriver: SQLiteDriverProtocol {
    public let database: SQLiteDatabase
    public var queryLogger: QueryLogger?

    /// Creates a new SQLiteDriver pointing
    /// to the database at the supplied path.
    public init(path: String) throws {
        self.database = SQLiteDatabase(storage: .file(path: path))
        try enableForeignKeys()
    }
}

public protocol SQLiteDriverProtocol: Driver, Connection, Transactable {
    var database: SQLiteDatabase { get }
}

extension SQLiteDriverProtocol {
    public var idKey: String {
        return "id"
    }

    public var idType: IdentifierType {
        return .int
    }

    public var keyNamingConvention: KeyNamingConvention {
        return .snake_case
    }

    public var isClosed: Bool {
        // TODO: FIXME
        return false
    }

    /// Executes the query.
    @discardableResult
    public func query<E>(_ query: RawOr<Query<E>>) throws -> Node {
        switch query {
        case .some(let query):
            if
                case .schema(let schema) = query.action,
                case .modify(let fields, let fks, let deleteFields, let deleteFks) = schema,
                (fields.count + fks.count + deleteFields.count + deleteFks.count) > 1
            {
                throw SQLiteDriverError.unsupported("SQLite does not support more than one ADD/DROP action per ALTER. Try splitting your modifications into separate queries. Attempted to ADD \(fields.count) columns, DROP \(deleteFields.count) columns, ADD \(fks.count) foreign keys, DROP \(fks.count) foreign keys.")
            }

            let serializer = SQLiteSerializer(query)
            let (statement, values) = serializer.serialize()
            queryLogger?.log(statement, values)
            let results = try database.execute(statement) { statement in
                try self.bind(statement: statement, to: values)
            }

            if query.action == .create {
                switch E.idType {
                case .int:
                    if let id = database.lastId {
                        return Node(id)
                    }
                case .uuid, .custom:
                    // sqlite annoyingly doesn't support anything
                    // besides integers for getting last ID.
                    // so we must manually pull the id from the data
                    // that was _provided_
                    return query.data[.some(E.idKey)]?.wrapped
                        ?? database.lastId?.makeNode(in: query.context)
                        ?? Node.null
                }
            }

            return map(results: results)
        case .raw(let statement, let values):
            queryLogger?.log(statement, values)
            let results = try database.execute(statement) { statement in
                try self.bind(statement: statement, to: values)
            }
            return map(results: results)
        }

    }

    /// Binds an array of values to the
    /// SQLite statement.
    func bind(statement: SQLite.Statement, to values: [Node]) throws {
        for value in values {
            switch value.wrapped {
            case .number(let number):
                switch number {
                case .int(let int):
                    try statement.bind(int)
                case .double(let double):
                    try statement.bind(double)
                case .uint(let uint):
                    try statement.bind(Int(uint))
                }
            case .string(let string):
                try statement.bind(string)
            case .array(_):
                throw SQLiteDriverError.unsupported("Array values not supported.")
            case .object(_):
                throw SQLiteDriverError.unsupported("Dictionary values not supported.")
            case .null:
                try statement.null()
            case .bool(let bool):
                try statement.bind(bool)
            case .bytes(let data):
                try statement.bind(data)
            case .date(let date):
                try statement.bind(date.makeNode(in: nil).string ?? "")
            }
        }
    }

    /// Maps SQLite Results to Fluent results.
    func map(results: [SQLite.Result.Row]) -> Node {
        let res: [Node] = results.map { row in
            var object: Node = .object([:])
            for (key, value) in row.data {
                object[key] = value.makeNode(in: rowContext)
            }
            return object
        }
        return .array(res)
    }

    public func makeConnection(_ type: ConnectionType) throws -> Connection {
        // SQLite must be configured with
        // SQLITE_OPEN_FULLMUTEX for this to work
        return self
    }

    public func enableForeignKeys() throws {
        try raw("PRAGMA foreign_keys = ON")
    }

    public func disableForeignKeys() throws {
        try raw("PRAGMA foreign_keys = OFF")
    }

    public func transaction<R>(_ closure: (Connection) throws -> R) throws -> R {
        let conn = try makeConnection(.readWrite)

        let rand = OSRandom()
            .bytes(count: 2)
            .hexEncoded
            .makeString()

        let name = "`_fluent_savepoint_\(rand)`"

        try conn.raw("SAVEPOINT \(name)")
        do {
            let value = try closure(conn)
            try conn.raw("RELEASE SAVEPOINT \(name)")
            return value
        } catch {
            try conn.raw("ROLLBACK TO SAVEPOINT \(name)")
            try conn.raw("RELEASE SAVEPOINT \(name)")
            throw error
        }
    }
}

/// Describes the errors this
/// driver can throw.
public enum SQLiteDriverError {
    case unsupported(String)
    case unspecified(Swift.Error)
}

extension SQLiteDriverError: Debuggable {
    public var identifier: String {
        switch self {
        case .unsupported(_):
            return "unsupported"
        case .unspecified(_):
            return "unspecified"
        }
    }

    public var reason: String {
        switch self {
        case .unsupported(let msg):
            return "Unsupported Command: \(msg)"
        case .unspecified(let error):
            return "Unspecified: \(error)"
        }
    }

    public var possibleCauses: [String] {
        return [
            "using operations not supported by sqlite"
        ]
    }

    public var suggestedFixes: [String] {
        return [
            "verify data is not corrupt if data type should be supported by sqlite"
        ]
    }
}
