/// Defines a `Filter` that can be
/// added on fetch, delete, and update
/// operations to limit the set of
/// data affected.
public struct Filter {
    /// The entity to filter.
    public var entity: String

    /// The method to filter by, comparison, subset, grouped, etc.
    public var method: FilterMethod

    /// Create a new filter.
    public init(entity: String, method: FilterMethod) {
        self.entity = entity
        self.method = method
    }
}

extension Filter: CustomStringConvertible {
    /// A readable description of this filter.
    public var description: String {
        switch method {
        case .equality(let field, let comparison, let value):
            return "(\(entity)) \(field) \(comparison) \(value)"
        case .order(let field, let comparison, let value):
            return "(\(entity)) \(field) \(comparison) \(value)"
        case .sequence(let field, let comparison, let value):
            return "(\(entity)) \(field) \(comparison) \(value)"
        case .subset(let field, let scope, let values):
            return "(\(entity)) \(field) \(scope) \(values)"
        case .group(let relation, let filters):
            return filters.map { $0.description }.joined(separator: "\(relation)")
        }
    }
}

extension QueryBuilder {
    /// Manually create and append filter
    @discardableResult
    public func addFilter(
        _ filter: Filter
    ) -> Self {
        query.filters.append(filter)
        return self
    }
}
