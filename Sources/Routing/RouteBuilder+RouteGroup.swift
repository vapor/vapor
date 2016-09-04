extension RouteBuilder {
    /**
        Creates a RouteGroup within a closure for
        nesting route building calls.
        
        - see RouteBuilder.grouped()
    */
    public func group(
        prefix: [String?],
        path: [String],
        map: ((Value) -> (Value))?,
        closure: (RouteGroup<Value, Self>) -> ()
    ) {
        let group = grouped(prefix: prefix, path: path, map: map)
        closure(group)
    }

    /**
        Creates a RouteGroup for adding nexted
        route building calls.

         - parameter prefix: An array of optional Strings that will override
            the beginning of the path if not-nil. For example:

                prefix = [nil, "foo"]
                incomingPath = ["1", "2", "3"]
                result = ["1", "foo", "3"]

            This allows the group to selectively override certain
            path components at will.

            Also note the path will be added **after** the prefix.

        - parameter path: The path to be added after the prefix count.
            For example:

                prefix = [nil, nil]
                path = ["foo"]
                incomingPath = ["1", "2", "3"]
                result = ["1", "2", "foo", "3"]

        - parameter map: Transforms the input Value to the return Value.
            Usefule for injecting middleware into a RouteGroup.
    */
    public func grouped(
        prefix: [String?],
        path: [String],
        map: ((Value) -> (Value))?
    ) -> RouteGroup<Value, Self> {
        return RouteGroup(
            builder: self,
            prefix: prefix,
            path: path,
            map: map
        )
    }
}
