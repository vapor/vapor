/// Possible relations between items in a group
public enum Relation {
    case and, or
}

extension QueryBuilder {
    /// Subset `in` filter.
    @discardableResult
    public func filter<
        Field: QueryFieldRepresentable
    >(_ field: Field, in values: [Encodable?]) throws -> Self {
        let method = FilterMethod.subset(field.makeQueryField(), .in, .array(values))
        let filter = Filter(entity: M.entity, method: method)
        return addFilter(filter)
    }

    /// Subset `notIn` filter.
    @discardableResult
    public func filter<
        Field: QueryFieldRepresentable
    >(_ field: Field, notIn values: [Encodable?]) throws -> Self {
        let method = FilterMethod.subset(field.makeQueryField(), .notIn, .array(values))
        let filter = Filter(entity: M.entity, method: method)
        return addFilter(filter)
    }
}
