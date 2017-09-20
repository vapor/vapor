/// Defines a `Filter` that can be
/// added on fetch, delete, and update
/// operations to limit the set of
/// data affected.
public struct Filter {
    public enum Relation {
        case and, or
    }

    public enum Method {
        case compare(String, Comparison, Node)
        case subset(String, Scope, [Node])
        case group(Relation, [RawOr<Filter>])
    }

    public init(_ entity: Entity.Type, _ method: Method) {
        self.entity = entity
        self.method = method
    }

    public var entity: Entity.Type
    public var method: Method
}

extension Filter: CustomStringConvertible {
    public var description: String {
        switch method {
        case .compare(let field, let comparison, let value):
            return "(\(entity)) \(field) \(comparison) \(value)"
        case .subset(let field, let scope, let values):
            let valueDescriptions = values.map { $0.string ?? "" }
            return "(\(entity)) \(field) \(scope) \(valueDescriptions)"
        case .group(let relation, let filters):
            return filters.map { $0.description }.joined(separator: "\(relation)")
        }
    }
}
