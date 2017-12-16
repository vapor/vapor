import Async
import CSQLite

/// Results from a SQLite query. Call `.fetchRow` to continue
/// fetching rows from this result set until there are none left.
public final class SQLiteResults {
    /// The raw query pointer
    private let raw: SQLiteQuery.Raw

    /// Parsed columns for this query
    private let columns: [SQLiteColumn]

    /// The connection we are executing on
    private var connection: SQLiteConnection

    /// The state of the results
    private var state: SQLiteResultsState

    /// Use `SQLiteQuery.execute` to create a `SQLiteResultStream`
    internal init(raw: SQLiteQuery.Raw, columns: [SQLiteColumn], on connection: SQLiteConnection) {
        self.raw = raw
        self.columns = columns
        self.connection = connection
        /// sqlite query will only create a result object if
        /// there are rows available
        state = .rowAvailable
    }

    /// Returns a future row. Returns nil if there
    /// are no more rows.
    public func fetchRow() -> Future<SQLiteRow?> {
        let promise = Promise(SQLiteRow?.self)

        // sqlite may block at anytime, so we need to run everything
        // on a separate background queue
        connection.background.async {
            do {
                // blocking execute now that we're on the background thread
                let row = try self.blockingFetchRow()
                // return to event loop
                self.connection.eventLoop.queue.async {
                    promise.complete(row)
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

    /// Fetches rows in blocking fashion. This should be called from a
    /// background thread.
    private func blockingFetchRow() throws -> SQLiteRow? {
        guard case .rowAvailable = state else {
            return nil
        }

        var row = SQLiteRow()

        // iterator over column count again and create a field
        // for each column. Use the column we have already initialized.
        for i in 0..<Int32(columns.count) {
            let col = columns[Int(i)]
            let field = try SQLiteField(query: raw, offset: i)
            row.fields[col] = field
        }


        // step over the query, this will continue to return SQLITE_ROW
        // for as long as there are new rows to be fetched
        if sqlite3_step(raw) != SQLITE_ROW {
            let ret = sqlite3_finalize(raw)
            guard ret == SQLITE_OK else {
                throw SQLiteError(statusCode: ret, connection: connection)
            }
            self.state = .exhausted
        }

        // return to event loop
        return row
    }
}

/// Potential result states
fileprivate enum SQLiteResultsState {
    case rowAvailable
    case exhausted
}
