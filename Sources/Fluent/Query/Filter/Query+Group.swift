public typealias QueryClosure<E: Model> = (Query<E>) throws -> ()

extension QueryRepresentable where Self: ExecutorRepresentable {
    /// Grouped filter closure with specified relation.
    @discardableResult
    public func group(
        _ relation: Filter.Relation,
        _ closure: QueryClosure<E>
    ) throws -> Query<E> {
        let main = try makeQuery()
        
        let sub = Query<E>(main.executor)
        try closure(sub)
        
        let group = Filter(E.self, .group(relation, sub.filters))
        try main.filter(group)
        
        return main
    }
    
    /// Grouped `and` filter subquery
    @discardableResult
    public func and(_ closure: QueryClosure<E>) throws -> Query<E> {
        return try group(.and, closure)
    }
    
    /// Grouped `or` filter subquery
    @discardableResult
    public func or(_ closure: QueryClosure<E>) throws -> Query<E> {
        return try group(.or, closure)
    }
}
