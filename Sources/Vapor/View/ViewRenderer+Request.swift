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
            "request": request.makeNode(in: nil)
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
        
        if var nodeObject = try context.makeNode(in: nil).object {
            nodeObject["request"] = try request.makeNode(in: nil)
            node = Node.object(nodeObject)
        } else {
            node = try context.makeNode(in: nil)
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
        
        context["request"] = try request.makeNode(in: nil)
        
        return try make(path, try context.makeNode(in: nil))
    }
}

extension Request {
    fileprivate func makeNode() throws -> Node {
        var nodeStorage: [String: Node] = [:]
        
        for (key, val) in storage {
            if let node = val as? NodeRepresentable {
                nodeStorage[key] = try node.makeNode(in: nil)
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
                "host": uri.hostname,
                "scheme": uri.scheme
            ])
        ])
    }
}
