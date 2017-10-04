/// Defines a `Filter` that can be
/// added on fetch, delete, and update
/// operations to limit the set of
/// data affected.
public struct Filter {
    public enum Relation {
        case and, or
    }

    public enum Method {
        case compare(String, Comparison, Encodable)
        case subset(String, Scope, [Encodable])
        case group(Relation, [RawOr<Filter>])
    }

    public init(_ entity: Model.Type, _ method: Method) {
        self.entity = entity
        self.method = method
    }

    public var entity: Model.Type
    public var method: Method
}

extension Filter: CustomStringConvertible {
    public var description: String {
        switch method {
        case .compare(let field, let comparison, let value):
            return "(\(entity)) \(field) \(comparison) \(value)"
        case .subset(let field, let scope, let values):
            return "(\(entity)) \(field) \(scope) \(values)"
        case .group(let relation, let filters):
            return filters.map { $0.description }.joined(separator: "\(relation)")
        }
    }
}
