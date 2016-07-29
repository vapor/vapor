extension RouteBuilder {
    public func group(
        prefix: [String?],
        path: [String],
        filter: ((Value) -> (Value))?,
        closure: (RouteGroup<Value, Self>) -> ()
        ) {
        let group = grouped(prefix: prefix, path: path, filter: filter)
        closure(group)
    }

    public func grouped(
        prefix: [String?],
        path: [String],
        filter: ((Value) -> (Value))?
        ) -> RouteGroup<Value, Self> {
        return RouteGroup(
            builder: self,
            prefix: prefix,
            path: path,
            filter: filter
        )
    }
}
