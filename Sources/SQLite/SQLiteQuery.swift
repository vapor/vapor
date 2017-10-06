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
    // stream conformance
    public typealias Output = SQLiteRow

    /// See OutputStream.OutputHandler
    public var outputStream: OutputHandler?

    /// See BaseStream.ErrorHandler
    public var errorStream: ErrorHandler?

    // raw pointers
    internal typealias Raw = OpaquePointer

    /// the raw statement pointer used for SQLite C API.
    internal let raw: Raw

    /// the database this statement will
    /// be executed on.
    public let connection: SQLiteConnection

    /// the raw query string
    public let statement: String

    /// current bind position
    var bindPosition: Int32

    /// next bind position.
    /// increments the current bind position.
    var nextBindPosition: Int32 {
        bindPosition += 1
        return bindPosition
    }

    /// Create a new SQLite statement with a supplied query string and database.
    ///
    /// The supplied DispatchQueue will be used to dispatch output stream calls.
    /// Make sure to supply the event loop to this parameter so you get called back
    /// on the appropriate thread.
    public init(statement: String, connection: SQLiteConnection) throws {
        var raw: Raw?
        let ret = sqlite3_prepare_v2(connection.raw, statement, -1, &raw, nil)
        guard ret == SQLITE_OK else {
            throw SQLiteError(statusCode: ret, connection: connection)
        }

        guard let statementPointer = raw else {
            throw SQLiteError(statusCode: ret, connection: connection)
        }

        self.connection = connection
        self.raw = statementPointer
        self.statement = statement

        bindPosition = 0
    }

    public func reset(_ statementPointer: OpaquePointer) {
        sqlite3_reset(statementPointer)
        sqlite3_clear_bindings(statementPointer)
    }

    /// Bind a Double to the current bind position.
    public func bind(_ value: Double) throws -> Self {
        let ret = sqlite3_bind_double(raw, nextBindPosition, value)
        guard ret == SQLITE_OK else {
            throw SQLiteError(statusCode: ret, connection: connection)
        }
        return self
    }

    /// Bind an Int to the current bind position.
    public func bind(_ value: Int) throws -> Self {
        let ret = sqlite3_bind_int64(raw, nextBindPosition, Int64(value))
        guard ret == SQLITE_OK else {
            throw SQLiteError(statusCode: ret, connection: connection)
        }
        return self
    }

    /// Bind a String to the current bind position.
    public func bind(_ value: String) throws -> Self {
        let strlen = Int32(value.utf8.count)
        let ret = sqlite3_bind_text(raw, nextBindPosition, value, strlen, SQLITE_TRANSIENT)
        guard ret == SQLITE_OK else {
            throw SQLiteError(statusCode: ret, connection: connection)
        }
        return self
    }

    /// Bind Bytes to the current bind position.
    public func bind(_ value: Foundation.Data) throws -> Self {
        let count = Int32(value.count)
        let pointer: UnsafePointer<Byte> = value.withUnsafeBytes { $0 }
        let ret = sqlite3_bind_blob(raw, nextBindPosition, UnsafeRawPointer(pointer), count, SQLITE_TRANSIENT)
        guard ret == SQLITE_OK else {
            throw SQLiteError(statusCode: ret, connection: connection)
        }
        return self
    }

    /// Bind a Bool to the current bind position.
    public func bind(_ value: Bool) throws -> Self {
        return try bind(value ? 1 : 0)
    }

    /// Binds null to the current bind position
    public func bindNull() throws -> Self {
        let ret = sqlite3_bind_null(raw, nextBindPosition)
        if ret != SQLITE_OK {
            throw SQLiteError(statusCode: ret, connection: connection)
        }
        return self
    }

    // MARK: Execute

    public func blockingExecute() throws {
        var columns: [SQLiteColumn] = []
        let count = sqlite3_column_count(self.raw)
        columns.reserveCapacity(Int(count))

        // iterate over column count and intialize columns once
        // we will then re-use the columns for each row
        for i in 0..<count {
            let column = try SQLiteColumn(statement: self, offset: i)
            columns.append(column)
        }

        // step over the query, this will continue to return SQLITE_ROW
        // for as long as there are new rows to be fetched
        while sqlite3_step(self.raw) == SQLITE_ROW {
            var row = SQLiteRow()

            // iterator over column count again and create a field
            // for each column. Use the column we have already initialized.
            for i in 0..<count {
                let col = columns[Int(i)]
                let field = try SQLiteField(statement: self, offset: i)
                row.fields[col] = field
            }

            // return to event loop
            self.connection.queue.async { self.outputStream?(row) }
        }

        // cleanup
        let ret = sqlite3_finalize(self.raw)
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
                self.connection.queue.async { promise.complete(()) }
            } catch {
                // return to event loop
                self.connection.queue.async { promise.fail(error) }
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
        execute().then {
            promise.complete(rows)
        }.catch { error in
            promise.fail(error)
        }

        return promise.future
    }
}
