#if OpenAPI
import OpenAPIKit
import Testing
@testable import VaporOpenAPI

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

private struct User: Decodable {
    var id: Int
}

private enum Role: String, Decodable {
    case admin
}

@Suite("Placeholders")
struct PlaceholderTests {
    @Test(
        "Every type with a builtin schema has a placeholder",
        arguments: [
            String.self as Any.Type, Bool.self,
            Int.self, Int64.self, Int32.self, Int16.self, Int8.self, Int128.self,
            UInt.self, UInt64.self, UInt32.self, UInt16.self, UInt8.self, UInt128.self,
            Double.self, Float.self, Decimal.self,
            Date.self, UUID.self, URL.self, Data.self,
        ]
    )
    func builtinTypes(type: Any.Type) {
        #expect(JSONSchema.builtin(for: type) != nil)
        #expect(Self.placeholder(for: type) != nil)
    }

    @Test("App types and containers have none, since they're decoded instead")
    func noPlaceholder() {
        #expect(Placeholder.value(for: User.self) == nil)
        #expect(Placeholder.value(for: Role.self) == nil)
        #expect(Placeholder.value(for: [Int].self) == nil)
        #expect(Placeholder.value(for: Int?.self) == nil)
        #expect(Placeholder.value(for: [String: Int].self) == nil)
    }

    /// `Placeholder.value(for:)` for a metatype only known at runtime.
    private static func placeholder(for type: Any.Type) -> Any? {
        func open<T>(_ type: T.Type) -> Any? { Placeholder.value(for: type) }
        return open(type)
    }
}
#endif
