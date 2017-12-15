import Async
import Bits
import CSQLite
import Dispatch
import Foundation

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// An executable statement. Use this to bind parameters to a query, and finally
/// execute the statement asynchronously.
///
///     try database.statement("INSERT INTO `foo` VALUES(?, ?)")
///         .bind(42)
///         .bind("Hello, world!")
///         .execute()
///         .then { ... }
///         .catch { ... }
///
public final class SQLiteQuery {
    // internal C api pointer for this query
    typealias Raw = OpaquePointer

    /// the database this statement will
    /// be executed on.
    public let connection: SQLiteConnection

    /// the raw query string
    public let string: String

    /// data bound to this query
    public var binds: [SQLiteData]

    /// Create a new SQLite statement with a supplied query string and database.
    internal init(string: String, connection: SQLiteConnection) {
        self.connection = connection
        self.string = string
        self.binds = []
    }

    /// Resets the query.
    public func reset(_ statementPointer: OpaquePointer) {
        sqlite3_reset(statementPointer)
        sqlite3_clear_bindings(statementPointer)
    }

    // MARK: Execute

    /// Starts executing the statement.
    public func execute() -> Future<SQLiteResults?> {
        let promise = Promise(SQLiteResults?.self)

        // sqlite may block at anytime, so we need to run everything
        // on a separate background queue
        connection.background.async {
            do {
                // blocking execute now that we're on the background thread
                let results = try self.blockingExecute()
                // return to event loop
                self.connection.eventLoop.queue.async {
                    promise.complete(results)
                }
            } catch {
                // return to event loop to output error
                self.connection.eventLoop.queue.async {
                    promise.fail(error)
                }
            }
        }

        return promise.future
    }

    /// Executes the query, blocking until complete.
    private func blockingExecute() throws -> SQLiteResults? {
        var columns: [SQLiteColumn] = []

        var raw: Raw?

        // log before anything happens, in case there's an error
        try connection.database.logger?.log(query: self).blockingAwait()

        let ret = sqlite3_prepare_v2(connection.raw, string, -1, &raw, nil)
        guard ret == SQLITE_OK else {
            throw SQLiteError(statusCode: ret, connection: connection)
        }

        guard let r = raw else {
            throw SQLiteError(statusCode: ret, connection: connection)
        }

        var nextBindPosition: Int32 = 1

        for bind in binds {
            switch bind {
            case .blob(let value):
                let count = Int32(value.count)
                let pointer: UnsafePointer<Byte> = value.withUnsafeBytes { $0 }
                let ret = sqlite3_bind_blob(r, nextBindPosition, UnsafeRawPointer(pointer), count, SQLITE_TRANSIENT)
                guard ret == SQLITE_OK else {
                    throw SQLiteError(statusCode: ret, connection: connection)
                }
            case .float(let value):
                let ret = sqlite3_bind_double(r, nextBindPosition, value)
                guard ret == SQLITE_OK else {
                    throw SQLiteError(statusCode: ret, connection: connection)
                }
            case .integer(let value):
                let ret = sqlite3_bind_int64(r, nextBindPosition, Int64(value))
                guard ret == SQLITE_OK else {
                    throw SQLiteError(statusCode: ret, connection: connection)
                }
            case .null:
                let ret = sqlite3_bind_null(r, nextBindPosition)
                if ret != SQLITE_OK {
                    throw SQLiteError(statusCode: ret, connection: connection)
                }
            case .text(let value):
                let strlen = Int32(value.utf8.count)
                let ret = sqlite3_bind_text(r, nextBindPosition, value, strlen, SQLITE_TRANSIENT)
                guard ret == SQLITE_OK else {
                    throw SQLiteError(statusCode: ret, connection: connection)
                }
            }

            nextBindPosition += 1
        }

        let count = sqlite3_column_count(r)
        columns.reserveCapacity(Int(count))

        // iterate over column count and intialize columns once
        // we will then re-use the columns for each row
        for i in 0..<count {
            let column = try SQLiteColumn(query: r, offset: i)
            columns.append(column)
        }

        let step = sqlite3_step(r)
        switch step {
        case SQLITE_DONE:
            // no results
            let ret = sqlite3_finalize(r)
            guard ret == SQLITE_OK else {
                throw SQLiteError(statusCode: ret, connection: connection)
            }

            return nil
        case SQLITE_ROW:
            /// there are results, lets fetch them
            return SQLiteResults(raw: r, columns: columns, on: connection)
        default:
            throw SQLiteError(statusCode: step, connection: connection)
        }
    }
}
