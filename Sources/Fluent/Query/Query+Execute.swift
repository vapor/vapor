import Async

/// Execute the database query.
extension QueryBuilder {
    /// Begins executing the connection and sending
    /// results to the output stream.
    /// The resulting future will be completed when the
    /// query is done or fails
    public func run<T: Decodable>(
        decoding type: T.Type = T.self,
        outputStream: @escaping BasicStream<T>.OutputHandler
    ) -> BasicStream<T> {
        let stream = BasicStream<T>()

        executor.then { conn in
            conn.execute(query: self.query, into: stream).then {
                stream.close()
            }.catch { err in
                stream.errorStream?(err)
            }
        }.catch { err in
            stream.errorStream?(err)
        }

        stream.outputStream = outputStream

        return stream
    }

    /// Convenience run that defaults to query builder's model.
    public func run(
        outputStream: @escaping BasicStream<M>.OutputHandler
    ) -> BasicStream<M> {
        return run(decoding: M.self, outputStream: outputStream)
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

        executor.then { conn in
            conn.execute(query: self.query, into: stream)
                .then(stream.close)
                .catch(promise.fail)
        }.catch(promise.fail)

        return promise.future
    }

    public func run() -> Future<Void> {
        let promise = Promise(Void.self)

        let stream = BasicStream<M>()
        executor.then { conn in
            conn.execute(query: self.query, into: stream)
                .then { promise.complete() }
                .catch(promise.fail)
            }.catch(promise.fail)

        return promise.future
    }
}
