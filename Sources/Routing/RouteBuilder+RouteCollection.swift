extension RouteBuilder {
    /**
        Adds a RouteCollection to the RouteBuilder
        by invoking the `.build` method.
    */
    public func collection<C: RouteCollection>(_ collection: C) where C.Wrapped == Value {
        collection.build(self)
    }
}
