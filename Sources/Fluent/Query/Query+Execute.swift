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

        executor.execute(query: self.query, into: stream).then {
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
        outputStream: @escaping BasicStream<M>.OutputHandler
    ) -> BasicStream<M> {
        return run(decoding: M.self, into: outputStream)
    }

    /// Executes the query, collecting the results
    /// into an array.
    /// The resulting array or an error will be resolved
    /// in the returned future.
    public func all() -> Future<[M]> {
        let promise = Promise([M].self)
        var models: [M] = []
        let stream = BasicStream<M>()

        stream.drain { model in
            models.append(model)
        }.catch { err in
            promise.fail(err)
        }.finally {
            promise.complete(models)
        }

        executor.execute(query: self.query, into: stream)
            .then(stream.close)
            .catch(promise.fail)

        return promise.future
    }

    /// Returns a future with the first result of the query.
    /// `nil` if no results were returned.
    public func first() -> Future<M?> {
        return limit(1).all().map { $0.first }
    }

    /// Runs a delete operation.
    public func delete() -> Future<Void> {
        query.action = .delete
        return run()
    }

    /// Runs the query, discarding any results.
    public func run() -> Future<Void> {
        let promise = Promise(Void.self)

        let stream = BasicStream<M>()
        executor.execute(query: self.query, into: stream)
            .then { promise.complete() }
            .catch(promise.fail)

        return promise.future
    }
}
