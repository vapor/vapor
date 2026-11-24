#if OpenAPI
import OpenAPIKit

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension JSONSchema {
    /// The schema for a standard library or Foundation type that encodes as a single JSON value,
    /// or `nil` if `type` isn't one of them.
    ///
    /// Containers such as arrays, optionals and dictionaries aren't listed: they're described
    /// from how they decode. These aren't conformances to `OpenAPISchemaProvider`, so an app
    /// can still conform one of these types itself to describe a different encoding.
    static func builtin(for type: Any.Type) -> JSONSchema? {
        builtinSchemas[ObjectIdentifier(type)]
    }

    /// Integer bounds as the `(value, exclusive:)` pairs OpenAPIKit takes.
    private static func bound<T: FixedWidthInteger>(_ value: T) -> (Int, exclusive: Bool) {
        (Int(value), exclusive: false)
    }

    private static let builtinSchemas: [ObjectIdentifier: JSONSchema] = [
        ObjectIdentifier(String.self): .string,
        ObjectIdentifier(Bool.self): .boolean,

        // Signed integers. `Int` is 64-bit on every platform Vapor runs on.
        ObjectIdentifier(Int.self): .integer(format: .int64),
        ObjectIdentifier(Int64.self): .integer(format: .int64),
        ObjectIdentifier(Int32.self): .integer(format: .int32),
        ObjectIdentifier(Int16.self): .integer(format: .int32, maximum: bound(Int16.max), minimum: bound(Int16.min)),
        ObjectIdentifier(Int8.self): .integer(format: .int32, maximum: bound(Int8.max), minimum: bound(Int8.min)),
        ObjectIdentifier(Int128.self): .integer,

        // Unsigned integers. Formats only describe signed sizes, so each uses the smallest signed
        // format that holds every value, plus a minimum of zero. `UInt64` doesn't fit in `int64`.
        ObjectIdentifier(UInt.self): .integer(minimum: bound(0 as UInt)),
        ObjectIdentifier(UInt64.self): .integer(minimum: bound(0 as UInt64)),
        ObjectIdentifier(UInt32.self): .integer(format: .int64, maximum: bound(UInt32.max), minimum: bound(UInt32.min)),
        ObjectIdentifier(UInt16.self): .integer(format: .int32, maximum: bound(UInt16.max), minimum: bound(UInt16.min)),
        ObjectIdentifier(UInt8.self): .integer(format: .int32, maximum: bound(UInt8.max), minimum: bound(UInt8.min)),
        ObjectIdentifier(UInt128.self): .integer(minimum: bound(0 as UInt128)),

        // Floating point.
        ObjectIdentifier(Double.self): .number(format: .double),
        ObjectIdentifier(Float.self): .number(format: .float),
        ObjectIdentifier(Decimal.self): .number,

        // Foundation values that `JSONEncoder` writes as strings.
        // Vapor's default JSON coders use ISO 8601 dates.
        ObjectIdentifier(Date.self): .string(format: .dateTime),
        ObjectIdentifier(UUID.self): .string(format: .uuid),
        // `uri` only allows absolute URLs, but `JSONEncoder` writes relative ones as they are.
        ObjectIdentifier(URL.self): .string(format: .uriReference),
        // OpenAPI 3.1 replaced the `byte` format with `contentEncoding`.
        ObjectIdentifier(Data.self): .string(contentEncoding: .base64),
    ]
}

#endif
