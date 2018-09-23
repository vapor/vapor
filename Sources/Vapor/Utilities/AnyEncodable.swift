/// A type erased encodable
public struct AnyEncodable: Encodable {
    /// The wrapped `ResponseEncodable` type.
    private let encodable: Encodable
    
    /// Creates a new `AnyEncodable`.
    ///
    /// - parameters:
    ///     - encodable: Something `Encodable`.
    public init(_ encodable: Encodable) {
        self.encodable = encodable
    }
    
    /// See `Encodable`.
    public func encode(to encoder: Encoder) throws {
        try encodable.encode(to: encoder)
    }
}
