import Async
import CSQLite

public final class SQLiteResultStream: OutputStream, ConnectionContext {
    // See OutputStream.Output
    public typealias Output = SQLiteRow

    /// The results
    private let results: SQLiteResults

    /// Use a basic stream to easily implement our output stream.
    private var downstream: AnyInputStream<Output>?

    /// Use `SQLiteResults.stream()` to create a `SQLiteResultStream`
    internal init(results: SQLiteResults) {
        self.results = results
    }

    /// See OutputStream.output
    public func output<S>(to inputStream: S) where S: Async.InputStream, S.Input == Output {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }

    /// See ConnectionContext.connection
    public func connection(_ event: ConnectionEvent) {
        switch event {
        case .cancel:
            /// FIXME: handle better
            break
        case .request(let count):
            guard count > 0 else {
                return
            }

            do {
                if let row = try results.fetchRow() {
                    self.downstream?.next(row)
                    self.request(count: count - 1)
                } else {
                    self.downstream?.close()
                }
            } catch {
                self.downstream?.error(error)
            }
        }
    }
}

/// MARK: Convenience

extension SQLiteResults {
    /// Create a SQLiteResultStream from these results
    public func stream() -> SQLiteResultStream {
        return .init(results: self)
    }
}

/// FIXME: move this to async

extension OutputStream {
    /// Convenience for gathering all rows into a single array.
    public func all() -> Future<[Output]> {
        let promise = Promise([Output].self)

        // cache the rows
        var rows: [Output] = []

        // drain the stream of results
        drain { upstream in
            upstream.request(count: .max)
        }.output { row in
            rows.append(row)
        }.catch { error in
            promise.fail(error)
        }.finally {
            promise.complete(rows)
        }

        return promise.future
    }
}
