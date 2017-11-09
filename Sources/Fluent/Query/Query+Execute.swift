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
    ) -> Future<Void> {
        let stream = BasicStream<T>()
        let promise = Promise(Void.self)

        // connect output
        stream.outputStream = outputStream

        // connect close
        stream.onClose = {
            promise.complete()
        }

        // connect error
        stream.errorStream = { error in
            promise.fail(error)
        }

        // execute
        connection.execute(query: self.query, into: stream)
        return promise.future
    }

    /// Convenience run that defaults to outputting a
    /// stream of the QueryBuilder's model type.
    public func run(
        outputStream: @escaping BasicStream<Model>.OutputHandler
    ) -> Future<Void> {
        return run(decoding: Model.self, into: outputStream)
    }

    /// Executes the query, collecting the results
    /// into an array.
    /// The resulting array or an error will be resolved
    /// in the returned future.
    public func all() -> Future<[Model]> {
        let promise = Promise([Model].self)
        var models: [Model] = []

        run { model in
            models.append(model)
        }.do {
            promise.complete(models)
        }.catch(promise.fail)

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
        return run { _ in }
    }
}

// MARK: Chunk

extension QueryBuilder {
    /// Accepts a chunk of models.
    public typealias ChunkClosure<T> = ([T]) throws -> ()

    /// Convenience for chunking model results.
    public func chunk(
        max: Int, closure: @escaping ChunkClosure<Model>
    ) -> Future<Void> {
        return chunk(decoding: Model.self, max: max, closure: closure)
    }

    /// Run the query, grouping the results into chunks before calling closure.
    public func chunk<T: Decodable>(
        decoding type: T.Type = T.self,
        max: Int, closure: @escaping ChunkClosure<T>
    ) -> Future<Void> {
        var partial: [T] = []
        partial.reserveCapacity(max)

        return self.run(decoding: T.self) { model in
            partial.append(model)
            if partial.count >= max {
                try closure(partial)
                partial = []
            }
        }.then {
            if partial.count > 0 {
                try closure(partial)
            }

            return .done
        }
    }
}
