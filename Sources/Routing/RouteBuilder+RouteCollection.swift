extension RouteBuilder {
    /**
        Adds a RouteCollection to the RouteBuilder
        by invoking the `.build` method.
    */
    public func collection<C: RouteCollection where C.Wrapped == Value>(_ collection: C) {
        collection.build(self)
    }
}
