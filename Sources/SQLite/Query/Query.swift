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
public final class SQLiteQuery: Async.OutputStream {
    // internal C api pointer for this query
    typealias Raw = OpaquePointer

    // stream conformance
    public typealias Output = SQLiteRow

    /// See OutputStream.OutputHandler
    public var outputStream: OutputHandler?

    /// See BaseStream.ErrorHandler
    public var errorStream: ErrorHandler?

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

    public func reset(_ statementPointer: OpaquePointer) {
        sqlite3_reset(statementPointer)
        sqlite3_clear_bindings(statementPointer)
    }

    // MARK: Execute

    public func blockingExecute() throws {
        var columns: [SQLiteColumn] = []

        var raw: Raw?

        // log before anything happens, in case there's an error
        try connection.database.logger?.log(query: self).blockingAwait()

        var ret = sqlite3_prepare_v2(connection.raw, string, -1, &raw, nil)
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


        // step over the query, this will continue to return SQLITE_ROW
        // for as long as there are new rows to be fetched
        while sqlite3_step(r) == SQLITE_ROW {
            var row = SQLiteRow()

            // iterator over column count again and create a field
            // for each column. Use the column we have already initialized.
            for i in 0..<count {
                let col = columns[Int(i)]
                let field = try SQLiteField(query: r, offset: i)
                row.fields[col] = field
            }

            // return to event loop
            self.connection.worker.eventLoop.queue.async {
                self.output(row)
            }
        }

        // cleanup
        ret = sqlite3_finalize(r)
        guard ret == SQLITE_OK else {
            throw SQLiteError(statusCode: ret, connection: self.connection)
        }
    }

    /// Starts executing the statement.
    public func execute() -> Future<Void> {
        // will alert when done
        let promise = Promise(Void.self)

        // sqlite may block at anytime, so we need to run everything
        // on a separate background queue
        connection.background.async {
            do {
                // blocking execute now that we're on the background thread
                try self.blockingExecute()

                // return to event loop
                self.connection.worker.eventLoop.queue.async {
                    promise.complete()
                }
            } catch {
                // return to event loop
                self.connection.worker.eventLoop.queue.async {
                    promise.fail(error)
                }
            }
        }

        return promise.future
    }

    /// Convenience for gathering all rows into a single array.
    public func all() throws -> Future<[SQLiteRow]> {
        let promise = Promise([SQLiteRow].self)

        // cache the rows
        var rows: [SQLiteRow] = []

        // drain the stream of results
        drain { row in
            rows.append(row)
        }.catch { error in
            promise.fail(error)
        }

        // start the statement's output stream
        execute().do {
            promise.complete(rows)
        }.catch { error in
            promise.fail(error)
        }

        return promise.future
    }
}
