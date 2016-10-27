import Auth
import Node
import Fluent

final class AuthUser: User {
    var id: Node?
    var name: String
    var exists: Bool = false
    
    init(name: String) {
        self.name = name
    }
    
    init(node: Node, in context: Context) throws {
        self.id = nil
        self.name = try node.extract("name")
    }
    
    func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "id": id,
            "name": name
        ])
    }
    
    static func prepare(_ database: Database) throws {
        
    }
    
    static func revert(_ database: Database) throws {
        
    }
    
    static func authenticate(credentials: Credentials) throws -> Auth.User {
        return AuthUser(name: "test")
    }
    
    
    static func register(credentials: Credentials) throws -> Auth.User {
        fatalError("\(#function) not supported")
    }
}
