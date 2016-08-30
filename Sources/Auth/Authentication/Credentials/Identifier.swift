import Node
import Turnstile

public struct Identifier: Credentials {
    public let id: Node

    public init(id: Node) {
        self.id = id
    }
}

extension Identifier {
    public init(id: NodeRepresentable) throws {
        self.init(id: try id.makeNode())
    }
}
