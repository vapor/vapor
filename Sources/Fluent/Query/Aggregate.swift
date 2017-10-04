extension QueryRepresentable where Self: ExecutorRepresentable {
    public func aggregate<D: Decodable>(_ agg: Aggregate) throws -> D {
        return try aggregate(nil, agg)
    }
    
    /// Aggregates the query on a single field, performing a specified operation.
    ///
    /// - Parameters:
    ///     - field: field to aggregate
    ///     - aggregate: the action to perform
    ///
    ///
    /// ```
    /// // find the sum of the age of all users
    /// User.aggregate("age", .sum)
    /// ```
    public func aggregate<D: Decodable>(_ field: String?, _ aggregate: Aggregate) throws -> D {
        let query = try makeQuery()
        query.action = Action.aggregate(field: field, aggregate)

        // FIXME: how to do this w/ codable?
        fatalError("aggregate not yet supported")
        // let raw = try query.raw()
        //return raw[0, "_fluent_aggregate"] ?? raw
    }
    
    public func aggregate<D: Decodable>(_ field: String?, raw: String) throws -> D {
        return try aggregate(field, .custom(string: raw))
    }
}

// MARK: Convenience

extension QueryRepresentable where Self: ExecutorRepresentable {
    public func count() throws -> Int {
        return try aggregate(.count) as Int
    }
}
