import HTTP

extension ViewRenderer {
    public func make(_ path: String, for request: Request) throws -> View {
        let context = try Node(node: [
            "request": request.makeNode()
        ])
        return try make(path, context)
    }
    
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
            "session": try session().data,
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
