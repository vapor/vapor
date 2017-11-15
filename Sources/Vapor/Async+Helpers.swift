import Async
import HTTP

/// Makes `Response` a drop-in replacement for `Future<Response>
extension Response: FutureType {
    public typealias Expectation = Response
}

extension String: FutureType {
    public typealias Expectation = String
}
