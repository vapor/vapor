#if OpenAPI
import OpenAPIKit
import Testing
@testable import VaporOpenAPI

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The builtin schema for `type` as compact JSON with sorted keys, or `nil` if there isn't one.
private func json(for type: Any.Type) throws -> String? {
    try JSONSchema.builtin(for: type).map { try json($0) }
}

private struct User: Codable {
    var id: Int
}

private enum Role: String, Codable {
    case admin
}

@Suite("Builtin schemas")
struct BuiltinSchemasTests {
    @Test(
        "Standard library and Foundation values have the schema of how they encode",
        arguments: [
            (String.self as Any.Type, #"{"type":"string"}"#),
            (Bool.self, #"{"type":"boolean"}"#),
            // Signed integers use the format that fits, with bounds below 32 bits.
            (Int.self, #"{"format":"int64","type":"integer"}"#),
            (Int64.self, #"{"format":"int64","type":"integer"}"#),
            (Int32.self, #"{"format":"int32","type":"integer"}"#),
            (Int16.self, #"{"format":"int32","maximum":32767,"minimum":-32768,"type":"integer"}"#),
            (Int8.self, #"{"format":"int32","maximum":127,"minimum":-128,"type":"integer"}"#),
            (Int128.self, #"{"type":"integer"}"#),
            // Unsigned integers have a minimum of zero, and a maximum where it fits.
            (UInt.self, #"{"minimum":0,"type":"integer"}"#),
            (UInt64.self, #"{"minimum":0,"type":"integer"}"#),
            (UInt32.self, #"{"format":"int64","maximum":4294967295,"minimum":0,"type":"integer"}"#),
            (UInt16.self, #"{"format":"int32","maximum":65535,"minimum":0,"type":"integer"}"#),
            (UInt8.self, #"{"format":"int32","maximum":255,"minimum":0,"type":"integer"}"#),
            (UInt128.self, #"{"minimum":0,"type":"integer"}"#),
            (Double.self, #"{"format":"double","type":"number"}"#),
            (Float.self, #"{"format":"float","type":"number"}"#),
            (Decimal.self, #"{"type":"number"}"#),
            // Foundation values that encode as strings carry their format.
            (Date.self, #"{"format":"date-time","type":"string"}"#),
            (UUID.self, #"{"format":"uuid","type":"string"}"#),
            (URL.self, #"{"format":"uri-reference","type":"string"}"#),
            // A base64 string, as in OpenAPI 3.1, not the old byte format.
            (Data.self, #"{"contentEncoding":"base64","type":"string"}"#),
        ]
    )
    func builtin(type: Any.Type, expected: String) throws {
        #expect(try json(for: type) == expected)
    }

    @Test(
        "Containers and app types aren't builtin, since they're described from how they decode",
        arguments: [[String].self as Any.Type, Set<Int>.self, [String: Int].self, Int?.self, User.self, Role.self]
    )
    func notBuiltin(type: Any.Type) throws {
        #expect(try json(for: type) == nil)
    }
}
#endif
