import Node
import URI
import HTTP
import Sessions

extension Request: NodeRepresentable {
    /**
        Converts the Request into a Node.
     
        Contains the following information:
            - Session
            - Storage
            - Method
            - Version
            - URI
    */
    public func makeNode(in context: Context?) throws -> Node {
        var nodeStorage: [String: Node] = [:]
        
        for (key, val) in storage {
            if let node = val as? NodeRepresentable {
                nodeStorage[key] = try node.makeNode(in: context)
            }
        }

        var node = Node(context)
        try node.set("session", try session())
        try node.set("storage", nodeStorage)
        try node.set("method", method.description)
        try node.set("version", version)
        try node.set("uri", uri)
        return node
    }
}

extension Session: NodeRepresentable {
    /**
        Converts the Session in a Node.
     
        Contains the following information:
            - Data
            - Identifier
    */
    public func makeNode(in context: Context? = nil) throws -> Node {
        var node = Node(context)
        try node.set("data", data)
        try node.set("identifier", identifier)
        return node
    }
}

extension Version: NodeRepresentable {
    /**
        Converts the Version in a Node.
     
        Contains the following information:
            - Major
            - Minor
            - Patch
    */
    public func makeNode(in context: Context?) throws -> Node {
        var node = Node(context)
        try node.set("major", major)
        try node.set("minor", minor)
        try node.set("patch", patch)
        return node
    }
}

extension URI: NodeRepresentable {
    /**
        Converts the URI in a Node.
     
        Contains the following information:
            - Path
            - Host
            - Scheme
    */
    public func makeNode(in context: Context?) throws -> Node {
        var node = Node(context)
        try node.set("path", path)
        try node.set("host", hostname)
        try node.set("scheme", scheme)
        return node
    }
}
