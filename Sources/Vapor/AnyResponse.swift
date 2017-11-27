import Async
import HTTP

/// A wrapper that helps disambiguate multiple response types within a single route
public struct AnyResponse: FutureType {
    /// AnyResponse represents any `ResponseEncodable`
    public typealias Expectation = AnyResponseType
    
    /// A wrapper around a `ResponseEncodable`
    public struct AnyResponseType: ResponseEncodable {
        /// The wrapped type
        var encodable: ResponseEncodable
        
        /// Encodes the response
        public func encode(to res: inout Response, for req: Request) throws -> Future<Void> {
            return try encodable.encode(to: &res, for: req)
        }
    }
    
    /// The wrapped entity
    var wrapped: Future<AnyResponseType>
    
    /// Locked method for adding an awaiter
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/async/advanced-futures/#adding-awaiters-to-all-results)
    public func addAwaiter(callback: @escaping (FutureResult<AnyResponseType>) -> ()) {
        wrapped.addAwaiter(callback: callback)
    }
    
    /// Wraps a non-futuretype response
    public init(_ encodable: ResponseEncodable) {
        wrapped = Future(AnyResponseType(encodable: encodable))
    }
    
    /// Wraps a future response encodable type
    public init<F: FutureType>(future encodable: F) where F.Expectation : ResponseEncodable {
        wrapped = encodable.map(AnyResponseType.init)
    }
}
