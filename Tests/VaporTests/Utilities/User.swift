import Vapor

final class User: StringInitializable, NodeConvertible {
    var id: Node?
    var name: String

    init?(from string: String) throws {
        if string == "ERROR" {
            return nil
        }
        
        self.name = string
    }
    
    init(name: String) {
        self.id = nil
        self.name = name
    }

    init(node: Node, in context: Context) throws {
        self.id = try node.get("id")
        self.name = try node.get("name")
    }

    func makeNode(context: Context) throws -> Node {
        return try  Node(node:["name": name])
    }
}
