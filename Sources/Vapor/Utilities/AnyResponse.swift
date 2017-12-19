import Async
import HTTP

/// A type erased resopnse.
public struct AnyResponse: ResponseEncodable {
    /// The wrapped type
    private let encodable: ResponseEncodable

    /// Wraps a non-futuretype response
    public init(_ encodable: ResponseEncodable) {
        self.encodable = encodable
    }

    /// Encodes the response
    public func encode(to res: inout Response, for req: Request) throws -> Future<Void> {
        return try encodable.encode(to: &res, for: req)
    }
}
