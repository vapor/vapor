import Async

/// Execute the database query.
extension QueryBuilder {
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
        return range(...1).all().map(to: Model?.self) { $0.first }
    }

    /// Runs a delete operation.
    public func delete() -> Completable {
        query.action = .delete
        return run()
    }

    /// Runs the query, discarding any results.
    public func run() -> Completable {
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
    ) -> Completable {
        return chunk(decoding: Model.self, max: max, closure: closure)
    }

    /// Run the query, grouping the results into chunks before calling closure.
    public func chunk<T: Decodable>(
        decoding type: T.Type = T.self,
        max: Int, closure: @escaping ChunkClosure<T>
    ) -> Completable {
        var partial: [T] = []
        partial.reserveCapacity(max)

        return run(decoding: T.self) { model in
            partial.append(model)
            if partial.count >= max {
                try closure(partial)
                partial = []
            }
        }.flatMap(to: Void.self) { 
            if partial.count > 0 {
                try closure(partial)
            }

            return .done
        }
    }
}
