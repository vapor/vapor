import Async
import CSQLite

public final class SQLiteResultStream: OutputStream {
    // See OutputStream.Output
    public typealias Output = SQLiteRow

    /// The results
    private let results: SQLiteResults

    /// Use a basic stream to easily implement our output stream.
    private var outputStream: BasicStream<Output>

    /// Use `SQLiteResults.stream()` to create a `SQLiteResultStream`
    internal init(results: SQLiteResults) {
        self.results = results
        self.outputStream = .init()
        outputStream.onRequestClosure = request
        outputStream.onCancelClosure = cancel
    }

    /// See OutputStream.output
    public func output<S>(to inputStream: S) where S: Async.InputStream, S.Input == Output {
        outputStream.output(to: inputStream)
    }

    /// Called when downstream asks for more output
    private func request(count: UInt) {
        guard count > 0 else {
            return
        }

        results.fetchRow().do { row in
            if let row = row {
                self.outputStream.onInput(row)
                self.request(count: count - 1)
            } else {
                self.outputStream.onClose()
            }
        }.catch { error in
            self.outputStream.onError(error)
        }
    }

    /// Called when downstream cancels output
    private func cancel() {
        self.outputStream.onClose()
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
        drain(1) { row, req in
            rows.append(row)
            req.requestOutput()
        }.catch { error in
            promise.fail(error)
        }.finally {
            promise.complete(rows)
        }

        return promise.future
    }
}
