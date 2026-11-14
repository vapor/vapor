#if OpenAPI
import OpenAPIKit

extension JSONSchema {
    /// The `components.schemas` name for `type`, without its module: `User`, `Outer.Inner`,
    /// `PageUser` for `Page<User>`.
    ///
    /// Not unique: same-named types from different modules or files get the same name.
    static func componentName(for type: Any.Type) -> String {
        var reflected = String(reflecting: type)
        // Drop the `(unknown context at $10a3c).` that qualifies private and local types.
        while let start = reflected.firstRange(of: "(unknown context at ") {
            guard let end = reflected[start.upperBound...].firstIndex(of: ")") else { break }
            var upperBound = reflected.index(after: end)
            if upperBound < reflected.endIndex, reflected[upperBound] == "." {
                upperBound = reflected.index(after: upperBound)
            }
            reflected.removeSubrange(start.lowerBound..<upperBound)
        }

        // Split into qualified names (`App.Outer.Inner`), drop each module, concatenate.
        // `.Cursor` after generic arguments (`App.Page<App.User>.Cursor`) has no module.
        let name =
            reflected
            .split(whereSeparator: { "<>[](),:? ".contains($0) })
            .map { path in
                let parts = path.split(separator: ".")
                let hasModule = path.first != "." && parts.count > 1
                return parts.dropFirst(hasModule ? 1 : 0).joined(separator: ".")
            }
            .joined()
            .componentKeySafe
        return name.isEmpty ? "Schema" : name
    }

    /// Whether to store this schema in `components.schemas`: objects, enums and compositions.
    ///
    /// Primitives, arrays and dictionaries stay inline, where a reference wouldn't be shorter.
    var isReferenceable: Bool {
        if allowedValues != nil {
            return true
        }
        switch value {
        case .object(_, let object):
            guard object.properties.isEmpty else { return true }
            switch object.additionalProperties {
            case .none: return true
            case .a(let allowed): return !allowed
            case .b: return false
            }
        case .all, .one, .any, .not:
            return true
        case .null, .boolean, .number, .integer, .string, .array, .reference, .dynamicReference, .fragment:
            return false
        }
    }

    /// The same schema, also allowing `null`.
    ///
    /// References and compositions become `anyOf: [schema, {type: null}]`, since
    /// `nullableSchemaObject()` ignores references and gives compositions a `type: null` that only
    /// `null` matches. `required`, and a reference's description, move to the `anyOf`. An enum
    /// also gets `null` among its values.
    func allowingNull() -> JSONSchema {
        switch value {
        case .reference(let reference, let core):
            return .any(
                of: [.reference(reference), .null()],
                core: .init(required: core.required, description: core.description)
            )
        case .any(of: let schemas, _) where schemas.contains(where: \.isNull):
            return self
        case .all, .one, .any, .not:
            return .any(of: [requiredSchemaObject(), .null()], core: .init(required: required))
        default:
            break
        }
        let nullable = nullableSchemaObject()
        guard let allowedValues, !allowedValues.contains(nil) else {
            return nullable
        }
        return nullable.with(allowedValues: allowedValues + [nil])
    }
}

#endif
