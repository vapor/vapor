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
    public func count(field: String? = nil) -> Future<Int> {
        let promise = Promise(Int.self)

        query.action = .aggregate(.count, field: nil)

        run(decoding: AggregateResult.self) { res in
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
internal struct AggregateResult: Decodable {
    var fluentAggregate: Int
}
