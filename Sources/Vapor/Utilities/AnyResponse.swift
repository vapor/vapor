import Async

/// A type erased response.
public struct AnyResponse: ResponseEncodable {
    /// The wrapped type
    private let encodable: ResponseEncodable

    /// Wraps a non-futuretype response
    public init(_ encodable: ResponseEncodable) {
        self.encodable = encodable
    }

    /// Encodes the response
    public func encode(for req: Request) throws -> Future<Response> {
        return try encodable.encode(for: req)
    }
}
