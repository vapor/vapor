import Async

/// Possible aggregation types.
public enum Aggregate {
    case count
    case sum
    case average
    case min
    case max
    case custom(string: String)
}

extension QueryBuilder {
    /// Get the number of results for this query.
    /// Optionally specify a specific field to count.
    public func count() -> Future<Int> {
        return aggregate(.count, field: nil)
    }

    /// Returns the sum of the supplied field
    public func sum(field: String) -> Future<Double> {
        return aggregate(.sum, field: field)
    }

    /// Returns the average of the supplied field
    public func average(field: String) -> Future<Double> {
        return aggregate(.average, field: field)
    }

    /// Returns the min of the supplied field
    public func min(field: String) -> Future<Double> {
        return aggregate(.min, field: field)
    }

    /// Returns the max of the supplied field
    public func max(field: String) -> Future<Double> {
        return aggregate(.max, field: field)
    }

    /// Perform an aggregate action on the supplied field.
    /// Decode as the supplied type.
    public func aggregate<D: Decodable>(
        _ aggregate: Aggregate,
        field: String?,
        as type: D.Type = D.self
    ) -> Future<D> {
        return self.aggregate(M.self, aggregate, field: field)
    }

    /// Perform an aggregate action on the supplied field
    /// on the supplied model.
    /// Decode as the supplied type.
    public func aggregate<M: Model, D: Decodable>(
        _ model: M.Type = M.self,
        _ aggregate: Aggregate,
        field: String?,
        as type: D.Type = D.self
    ) -> Future<D> {
        let promise = Promise(D.self)

        query.action = .aggregate(aggregate, entity: M.entity, field: field)

        run(decoding: AggregateResult<D>.self) { res in
            promise.complete(res.fluentAggregate)
        }.catch { err in
            promise.fail(err)
        }.finally {
            promise.fail("no agggregate")
        }

        return promise.future
    }
}

/// Aggreagate result structure expected from DB.
internal struct AggregateResult<D: Decodable>: Decodable {
    var fluentAggregate: D
}
