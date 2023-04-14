import NIOCore

/// A type erased response useful for routes that can return more than one type.
///
///     router.get("foo") { req -> AnyAsyncResponse in
///         if /* something */ {
///             return AnyAsyncResponse(42)
///         } else {
///             return AnyAsyncResponse("string")
///         }
///     }
///
/// This can also be done using a `AsyncResponseEncodable` enum.
///
///     enum IntOrString: AsyncResponseEncodable {
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
public struct AnyAsyncResponse: Sendable, AsyncResponseEncodable {
    /// The wrapped `AsyncResponseEncodable` type.
    private let encodable: AsyncResponseEncodable

    /// Creates a new `AnyAsyncResponse`.
    ///
    /// - parameters:
    ///     - encodable: Something `AsyncResponseEncodable`.
    public init(_ encodable: AsyncResponseEncodable) {
        self.encodable = encodable
    }

    public func encodeResponse(for request: Request) async throws -> Response {
        return try await self.encodable.encodeResponse(for: request)
    }
}

