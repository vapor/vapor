import Async

/// A stream of query results.
public final class QueryResultStream<Model, Database>: Async.OutputStream
    where Model: Decodable, Database: Fluent.Database
{
    // See OutputStream.Output
    public typealias Output = Model

    /// Maps output
    typealias OutputMap = (Model, Database.Connection) throws -> (Model)

    /// Use to transform output before it is delivered
    internal var outputMap: OutputMap?

    /// Use a basic stream to easily implement our output stream.
    private var outputStream: BasicStream<Output>

    /// Use a basic stream for fetching input from the connection
    private var inputStream: BasicStream<Output>

    /// Current output request
    private var outputRequest: OutputRequest?

    /// Pointer to the connection
    private var connection: Database.Connection?

    /// Use `SQLiteResults.stream()` to create a `SQLiteResultStream`
    internal init(query: DatabaseQuery, on connection: Future<Database.Connection>) {
        self.outputStream = .init()
        self.inputStream = .init()

        outputStream.onRequestClosure = request
        outputStream.onCancelClosure = cancel

        inputStream.onInputClosure = onInput
        inputStream.onErrorClosure = onError
        inputStream.onCloseClosure = onClose
        inputStream.onOutputClosure = onOutput

        connection.do { connection in
            self.connection = connection
            connection.execute(query: query, into: self.inputStream)
            }.catch { error in
                self.outputStream.onError(error)
                self.outputStream.onClose()
        }
    }

    /// See OutputStream.output(to:)
    public func output<S>(to inputStream: S) where S: Async.InputStream, S.Input == Output {
        outputStream.output(to: inputStream)
    }

    /// Called when downstream asks for more output
    private func request(count: UInt) {
        outputRequest?.requestOutput(count)
    }

    /// Called when downstream cancels output
    private func cancel() {
        outputRequest?.cancelOutput()
        onClose()
    }

    /// Called when the input stream gets new input
    private func onInput(_ input: Output) {
        if let map = outputMap, let conn = connection {
            do {
                let mapped = try map(input, conn)
                outputStream.onInput(mapped)
            } catch {
                outputStream.onError(error)
            }
        } else {
            outputStream.onInput(input)
        }
    }

    /// Called when the input stream gets an error
    private func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// Called when the input stream is closed
    private func onClose() {
        outputStream.onClose()
    }

    /// Called when the input stream is connected to an output stream
    private func onOutput(_ outputRequest: OutputRequest) {
        self.outputRequest = outputRequest
    }
}

