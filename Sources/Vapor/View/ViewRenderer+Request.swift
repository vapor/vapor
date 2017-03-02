import HTTP

extension ViewRenderer {
    /// 
    /// Creates a view at the given path
    /// using a Request as the data that will
    /// be supplied to the view.
    /// 
    /// Data from the `Request` is available in the
    /// view under the key "request".
    public func make(_ path: String, for request: Request) throws -> View {
        let context = try Node(node: [
            "request": request.makeNode()
        ])
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
        let node: Node
        
        if case .object(var nodeObject) = try context.makeNode() {
            nodeObject["request"] = try request.makeNode()
            node = Node.object(nodeObject)
        } else {
            node = try context.makeNode()
        }
        
        return try make(path, node)
    }
    
    /// Creates a view at the given path
    /// using a `NodeRepresentable` dictionary
    /// that will be merged with the given `Request`
    /// and supplied as the data to the view.
    ///
    /// Data from the `Request` is available in the
    /// view under the key "request".
    public func make(_ path: String, _ context: [String: NodeRepresentable], for request: Request) throws -> View {
        var context = context
        
        context["request"] = try request.makeNode()
        
        return try make(path, try context.makeNode())
    }
}

extension Request {
    fileprivate func makeNode() throws -> Node {
        var nodeStorage: [String: Node] = [:]
        
        for (key, val) in storage {
            if let node = val as? NodeRepresentable {
                nodeStorage[key] = try node.makeNode()
            }
        }
        
        return try Node(node: [
            "session": Node(node: [
                "data": try session().data,
                "identifier": try session().identifier
            ]),
            "storage": Node.object(nodeStorage),
            "method": method.description,
            "uri": Node(node: [
                "path": uri.path,
                "host": uri.host,
                "scheme": uri.scheme
            ])
        ])
    }
}
