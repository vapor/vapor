import Async

/// Execute the database query.
extension QueryBuilder {
    /// Begins executing the connection and sending
    /// results to the output stream.
    /// The resulting future will be completed when the
    /// query is done or fails
    public func run<T: Decodable>(
        decoding type: T.Type = T.self,
        into outputStream: @escaping BasicStream<T>.OutputHandler
    ) -> BasicStream<T> {
        let stream = BasicStream<T>()

        connection.execute(query: self.query, into: stream).do {
            stream.close()
        }.catch { err in
            stream.errorStream?(err)
        }

        stream.outputStream = outputStream

        return stream
    }

    /// Convenience run that defaults to outputting a
    /// stream of the QueryBuilder's model type.
    public func run(
        outputStream: @escaping BasicStream<Model>.OutputHandler
    ) -> BasicStream<Model> {
        return run(decoding: Model.self, into: outputStream)
    }

    /// Executes the query, collecting the results
    /// into an array.
    /// The resulting array or an error will be resolved
    /// in the returned future.
    public func all() -> Future<[Model]> {
        let promise = Promise([Model].self)
        var models: [Model] = []
        let stream = BasicStream<Model>()

        stream.drain { model in
            models.append(model)
        }.catch { err in
            promise.fail(err)
        }.finally {
            promise.complete(models)
        }

        connection.execute(query: self.query, into: stream)
            .do(stream.close)
            .catch(promise.fail)

        return promise.future
    }

    /// Returns a future with the first result of the query.
    /// `nil` if no results were returned.
    public func first() -> Future<Model?> {
        return range(...1).all().map { $0.first }
    }

    /// Runs a delete operation.
    public func delete() -> Future<Void> {
        query.action = .delete
        return run()
    }

    /// Runs the query, discarding any results.
    public func run() -> Future<Void> {
        let stream = BasicStream<Model>()
        return connection.execute(query: self.query, into: stream)
    }
}
