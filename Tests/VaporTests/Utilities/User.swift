import Vapor
import Fluent

final class User: Model {
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
        self.id = try node.extract("id")
        self.name = try node.extract("name")
    }

    func makeNode(context: Context) throws -> Node {
        return try  Node(node:[
            "id": id,
            "name": name
            ])
    }

    static func prepare(_ db: Database) throws { }
    static func revert(_ db: Database) throws { }
}
