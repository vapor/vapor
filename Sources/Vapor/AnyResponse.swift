import Async

/// A wrapper that helps disambiguate multiple response types within a single route
public struct AnyResponse: FutureType {
    /// AnyResponse represents any `ResponseEncodable`
    public typealias Expectation = ResponseEncodable
    
    /// The wrapped entity
    var wrapped: Future<ResponseEncodable>
    
    /// Locked method for adding an awaiter
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/async/advanced-futures/#adding-awaiters-to-all-results)
    public func addAwaiter(callback: @escaping (FutureResult<ResponseEncodable>) -> ()) {
        wrapped.addAwaiter(callback: callback)
    }
    
    /// Wraps a non-futuretype response
    public init(_ encodable: ResponseEncodable) {
        wrapped = Future(encodable)
    }
    
    /// Wraps a future response encodable type
    public init<F: FutureType>(future encodable: F) where F.Expectation : ResponseEncodable {
        wrapped = encodable.map { $0 }
    }
}
