import Async

/// Execute the database query.
extension QueryBuilder {
    /// Begins executing the connection and sending
    /// results to the output stream.
    /// The resulting future will be completed when the
    /// query is done or fails
    public func execute<T: Decodable>(
        decoding type: T.Type = T.self,
        outputStream: @escaping BasicStream<T>.OutputHandler
    ) -> BasicStream<T> {
        let stream = BasicStream<T>()

        connection.then { conn in
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

    /// Executes the query, collecting the results
    /// into an array.
    /// The resulting array or an error will be resolved
    /// in the returned future.
    public func all() -> Future<[M]> {
        let promise = Promise([M].self)

        var models: [M] = []

        execute(decoding: M.self) { model in
            models.append(model)
        }.catch { err in
            promise.fail(err)
        }.finally {
            promise.complete(models)
        }


        return promise.future
    }
}
