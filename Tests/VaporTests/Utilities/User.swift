import Vapor
import Node
import Routing

final class User: Parameterizable, NodeConvertible {
    var id: Node?
    var name: String

    static func make(for string: String) throws -> User {
        if string == "ERROR" {
            throw Abort.notFound
        }
        
        return User(name: string)
    }
    
    static var uniqueSlug: String {
        return "user"
    }
    
    init(name: String) {
        self.id = nil
        self.name = name
    }

    init(node: Node) throws {
        self.id = try node.get("id")
        self.name = try node.get("name")
    }

    func makeNode(in context: Context?) throws -> Node {
        return try  Node(node:["name": name])
    }
}
