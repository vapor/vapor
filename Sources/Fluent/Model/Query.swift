import Async

/// A Fluent database query.
public final class Query<M: Model>: OutputStream {
    // MARK: Stream

    /// See OutputStream.Output
    public typealias Output = M

    /// See OutputStream.outputStream
    public var outputStream: OutputHandler?

    /// See BaseStream.errorStream
    public var errorStream: ErrorHandler?

    // MARK: Fluent

    /// Result stream will be filtered by these queries.
    public var filters: [Filter]

    /// Optional model data to save or update.
    public var data: M?

    /// The connection this query will be excuted on.
    public let connection: Future<DatabaseConnection>

    // TEMP
    public var sql: String?

    /// Create a new query.
    public init(
        _ type: M.Type = M.self,
        on connection: Future<DatabaseConnection>
    ) {
        self.connection = connection
        self.filters = []
    }

    /// Begins executing the connection and sending
    /// results to the output stream.
    /// The resulting future will be completed when the
    /// query is done or fails
    public func execute() -> Future<Void> {
        let promise = Promise(Void.self)

        connection.then { conn in
            conn.execute(self).then {
                promise.complete(())
            }.catch { err in
                promise.fail(err)
            }
        }.catch { err in
            promise.fail(err)
        }

        return promise.future
    }

    /// Executes the query, collecting the results
    /// into an array.
    /// The resulting array or an error will be resolved
    /// in the returned future.
    public func all() -> Future<[M]> {
        let promise = Promise([M].self)

        var models: [M] = []
        drain { model in
            models.append(model)
        }.catch { err in
            promise.fail(err)
        }

        execute().then {
            promise.complete(models)
        }.catch { err in
            promise.fail(err)
        }

        return promise.future
    }
}

public struct Filter { }
