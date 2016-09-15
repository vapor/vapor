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

    init(node: Node, in context: Context) throws {
        self.id = nil
        self.name = try node.extract("name")
    }

    func makeNode(context: Context = EmptyNode) -> Node {
        return .null
    }

    static func prepare(_ db: Database) {}
    static func revert(_ db: Database) {}
}
