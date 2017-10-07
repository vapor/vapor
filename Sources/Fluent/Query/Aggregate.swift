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

struct AggregateResult: Decodable {
    var fluentAggregate: Int
}

extension QueryBuilder {
    /// Get the number of results for this query.
    /// Optionally specify a specific field to count.
    public func count(field: String? = nil) -> Future<Int> {
        let promise = Promise(Int.self)

        query.action = .aggregate(field: nil, .count)
        let stream = BasicStream<AggregateResult>()

        stream.drain { row in
            promise.complete(row.fluentAggregate)
        }.catch { err in
            promise.fail(err)
        }

        connection.then { conn in
            conn.execute(query: self.query, into: stream).then {
                promise.fail("never completed")
            }.catch(callback: promise.fail)
        }.catch(callback: promise.fail)

        return promise.future
    }
}


public final class BasicStream<Data>: Stream, ClosableStream {

    public typealias Input = Data
    public typealias Output = Data

    public var errorStream: ErrorHandler?
    public var outputStream: OutputHandler?
    public var onClose: CloseHandler?
    public func inputStream(_ input: Data) {
        outputStream?(input)
    }
}

extension ClosableStream {
    public func close() {
        onClose?()
    }
}
