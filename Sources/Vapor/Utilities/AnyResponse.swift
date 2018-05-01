/// A type erased response useful for routes that can return more than one type.
///
///     router.get("foo") { req -> AnyResponse in
///         if /* something */ {
///             return AnyResponse(42)
///         } else {
///             return AnyResponse("string")
///         }
///     }
///
/// This can also be done using a `ResponseEncodable` enum.
///
///     enum IntOrString: ResponseEncodable {
///         case int(Int)
///         case string(String)
///
///         func encode(for req: Request) throws -> EventLoopFuture<Response> {
///             switch self {
///             case .int(let i): return try i.encode(for: req)
///             case .string(let s): return try s.encode(for: req)
///             }
///         }
///     }
///
///     router.get("foo") { req -> IntOrString in
///         if /* something */ {
///             return .int(42)
///         } else {
///             return .string("string")
///         }
///     }
///
public struct AnyResponse: ResponseEncodable {
    /// The wrapped `ResponseEncodable` type.
    private let encodable: ResponseEncodable

    /// Creates a new `AnyResponse`.
    ///
    /// - parameters:
    ///     - encodable: Something `ResponseEncodable`.
    public init(_ encodable: ResponseEncodable) {
        self.encodable = encodable
    }

    /// See `ResponseEncodable`.
    public func encode(for req: Request) throws -> Future<Response> {
        return try encodable.encode(for: req)
    }
}
