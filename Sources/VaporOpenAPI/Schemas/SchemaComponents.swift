#if OpenAPI
import OpenAPIKit

/// Collects `components.schemas` and hands out `$ref`s to them.
///
/// Names are keyed by type, so same-named types get `User`, `User2`…
struct SchemaComponents: Sendable, Equatable {
    private(set) var schemas: OrderedDictionary<OpenAPI.ComponentKey, JSONSchema> = [:]
    /// Names of stored types and of types being described.
    private var names: [ObjectIdentifier: OpenAPI.ComponentKey] = [:]
    /// Types with a `$ref` handed out, whose component must exist.
    private var referenced: Set<ObjectIdentifier> = []

    /// A `$ref` to `type`'s component, or its schema inline.
    ///
    /// `describe` builds the schema and may recurse for nested types. The name is reserved first,
    /// so a recursive type refers to itself. Non-``JSONSchema/isReferenceable`` schemas stay
    /// inline unless already referred to. If `describe` throws, nothing it added is kept.
    mutating func schema(
        for type: Any.Type,
        describe: (inout SchemaComponents) throws -> JSONSchema
    ) rethrows -> JSONSchema {
        if let reference = reference(to: type) {
            return reference
        }
        let id = ObjectIdentifier(type)

        let componentName = JSONSchema.componentName(for: type)
        var candidate = componentName
        var suffix = 2
        while names.values.contains(where: { $0.rawValue == candidate }) {
            candidate = componentName + "\(suffix)"
            suffix += 1
        }
        guard let key = OpenAPI.ComponentKey(rawValue: candidate) else {
            preconditionFailure("componentName(for:) made an invalid component key: \(candidate)")
        }

        let saved = self
        names[id] = key
        let schema: JSONSchema
        do {
            schema = try describe(&self)
        } catch {
            // Drop components added meanwhile too: they may refer to this type.
            self = saved
            throw error
        }

        guard schema.isReferenceable || referenced.contains(id) else {
            names[id] = nil
            return schema
        }
        schemas[key] = schema
        return .reference(.component(named: key.rawValue))
    }

    /// A `$ref` to `type`'s component if it's stored or being described, so it needn't be
    /// described again.
    mutating func reference(to type: Any.Type) -> JSONSchema? {
        let id = ObjectIdentifier(type)
        guard let key = names[id] else { return nil }
        referenced.insert(id)
        return .reference(.component(named: key.rawValue))
    }

    /// Takes back `type`'s component, unless something refers to it or it was already stored in
    /// `earlier`, so a type only described to read its properties doesn't stay in the document.
    mutating func discard(_ type: Any.Type, keepingWhatsIn earlier: SchemaComponents) {
        let id = ObjectIdentifier(type)
        guard let key = names[id], earlier.names[id] == nil, !referenced.contains(id) else { return }
        names[id] = nil
        schemas[key] = nil
    }
}

#endif
