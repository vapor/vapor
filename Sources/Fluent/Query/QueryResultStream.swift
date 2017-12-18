import Async

/// A stream of query results.
public final class QueryResultStream<Model, Database>: Async.Stream
    where Model: Decodable, Database: Fluent.Database
{
    /// See InputStream.Input
    public typealias Input = Model

    // See OutputStream.Output
    public typealias Output = Model

    /// Maps output
    typealias OutputMap = (Model, Database.Connection) throws -> (Model)

    /// Use to transform output before it is delivered
    internal var outputMap: OutputMap?

    /// Use a basic stream to easily implement our output stream.
    private var downstream: AnyInputStream<Output>?

    /// Use a basic stream to easily implement our output stream.
    private var upstream: ConnectionContext?

    /// Pointer to the connection
    private var connection: Database.Connection?

    /// Use `SQLiteResults.stream()` to create a `SQLiteResultStream`
    internal init(query: DatabaseQuery, on connection: Future<Database.Connection>) {
        connection.do { connection in
            self.connection = connection
            connection.execute(query: query, into: self)
        }.catch { error in
            self.error(error)
            self.close()
        }
    }

    public func input(_ event: InputEvent<Model>) {
        switch event {
        case .close:
            downstream?.close()
        case .connect(let upstream):
            self.upstream = upstream
            /// act as a passthrough stream
            downstream?.connect(to: upstream)
        case .error(let error): downstream?.error(error)
        case .next(let input):
            if let map = outputMap, let conn = connection {
                do {
                    let mapped = try map(input, conn)
                    downstream?.next(mapped)
                } catch {
                    downstream?.error(error)
                }
            } else {
                downstream?.next(input)
            }
        }
    }

    /// See OutputStream.output(to:)
    public func output<S>(to inputStream: S) where S: Async.InputStream, S.Input == Output {
        downstream = AnyInputStream(inputStream)
        /// act as a passthrough stream
        upstream.flatMap(inputStream.connect)
    }
}

