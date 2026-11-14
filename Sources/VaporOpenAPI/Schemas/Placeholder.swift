#if OpenAPI
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Stand-in values for the types with a builtin schema, so a fake decoder can return one without
/// running the type's own `init(from:)`, which may reject a made-up value (`UUID` from `""`).
enum Placeholder {
    /// A value of `type`, or `nil` if it isn't a standard library or Foundation leaf type.
    static func value<T>(for type: T.Type) -> T? {
        // Unwrap first: a missing value cast to an optional `T` would succeed as `.some(nil)`.
        guard let value = values[ObjectIdentifier(type)] else { return nil }
        return value as? T
    }

    private static let values: [ObjectIdentifier: any Sendable] = {
        var values: [ObjectIdentifier: any Sendable] = [
            ObjectIdentifier(String.self): "",
            ObjectIdentifier(Bool.self): false,
            ObjectIdentifier(Int.self): 0 as Int,
            ObjectIdentifier(Int64.self): 0 as Int64,
            ObjectIdentifier(Int32.self): 0 as Int32,
            ObjectIdentifier(Int16.self): 0 as Int16,
            ObjectIdentifier(Int8.self): 0 as Int8,
            ObjectIdentifier(Int128.self): 0 as Int128,
            ObjectIdentifier(UInt.self): 0 as UInt,
            ObjectIdentifier(UInt64.self): 0 as UInt64,
            ObjectIdentifier(UInt32.self): 0 as UInt32,
            ObjectIdentifier(UInt16.self): 0 as UInt16,
            ObjectIdentifier(UInt8.self): 0 as UInt8,
            ObjectIdentifier(UInt128.self): 0 as UInt128,
            ObjectIdentifier(Double.self): 0 as Double,
            ObjectIdentifier(Float.self): 0 as Float,
            ObjectIdentifier(Decimal.self): 0 as Decimal,
            ObjectIdentifier(Date.self): Date(timeIntervalSince1970: 0),
            ObjectIdentifier(UUID.self): UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
            ObjectIdentifier(Data.self): Data(),
        ]
        if let url = URL(string: "https://example.com") {
            values[ObjectIdentifier(URL.self)] = url
        }
        return values
    }()
}

#endif
