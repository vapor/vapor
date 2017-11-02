/// Possible relations between items in a group
public enum QueryGroupRelation {
    case and, or
}

extension QueryBuilder {
    /// Subset `in` filter.
    @discardableResult
    public func filter<
        Field: QueryFieldRepresentable
    >(_ field: Field, in values: [Encodable?]) throws -> Self {
        let filter = QueryFilter(
            entity: M.entity,
            method: .subset(field.makeQueryField(), .in, .array(values))
        )
        return addFilter(filter)
    }

    /// Subset `notIn` filter.
    @discardableResult
    public func filter<
        Field: QueryFieldRepresentable
    >(_ field: Field, notIn values: [Encodable?]) throws -> Self {
        let filter = QueryFilter(
            entity: M.entity,
            method: .subset(field.makeQueryField(), .notIn, .array(values))
        )
        return addFilter(filter)
    }
}
