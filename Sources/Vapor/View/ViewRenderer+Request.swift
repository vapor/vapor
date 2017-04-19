import HTTP

extension ViewRenderer {
    /// Creates a view at the given path
    /// using a Request as the data that will
    /// be supplied to the view.
    /// 
    /// Data from the `Request` is available in the
    /// view under the key "request".
    public func make(_ path: String, for request: Request) throws -> View {
        var context = Node(ViewContext.shared)
        try context.set("request", request)
        return try make(path, context)
    }
    
    /// Creates a view at the given path
    /// using a `NodeRepresentable` context
    /// that will be merged with the given `Request`
    /// and supplied as the data to the view.
    /// 
    /// Data from the `Request` is available in the
    /// view under the key "request".
    public func make(_ path: String, _ context: NodeRepresentable, for request: Request) throws -> View {
        var context = try context.makeNode(in: ViewContext.shared)
        try context.set("request", request)
        return try make(path, context)
    }
}
