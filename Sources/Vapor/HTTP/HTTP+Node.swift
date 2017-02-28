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
    public func makeNode(in context: Context) throws -> Node {
        var nodeStorage: [String: Node] = [:]
        
        for (key, val) in storage {
            if let node = val as? NodeRepresentable {
                nodeStorage[key] = try node.makeNode(in: context)
            }
        }
        
        return try Node(node: [
            "session": try session().makeNode(in: context),
            "storage": Node.object(nodeStorage),
            "method": method.description,
            "version": version.makeNode(in: context),
            "uri": uri.makeNode(in: context)
        ])
    }
}

extension Session: NodeRepresentable {
    /**
        Converts the Session in a Node.
     
        Contains the following information:
            - Data
            - Identifier
    */
    public func makeNode(in context: Context) throws -> Node {
        return try Node(node: [
            "data": data,
            "identifier": identifier
        ])
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
    public func makeNode(in context: Context) throws -> Node {
        return try Node(node: [
            "major": major,
            "minor": minor,
            "patch": patch
        ])
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
    public func makeNode(in context: Context) throws -> Node {
        return try Node(node: [
            "path": path,
            "host": host,
            "scheme": scheme
        ])
    }
}
