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

        execute(decoding: AggregateResult.self) { res in
            promise.complete(res.fluentAggregate)
        }.catch { err in
            promise.fail(err)
        }.finally {
            promise.fail("did not complete")
        }

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

    public func finally(_ onClose: @escaping CloseHandler) {
        self.onClose = onClose
    }
}
