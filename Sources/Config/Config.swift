@_exported import Node

public struct Config {
    internal var node: Node

    public init(_ node: Node) {
        self.node = node
    }

    public init(prioritized: [Source]) throws {
        self.node = try Node.makeConfig(prioritized: prioritized)
    }
}

extension Config: NodeConvertible {
    public init(node: Node, in context: Context) throws {
        self.init(node)
    }
    public func makeNode() throws -> Node {
        return node
    }
}

extension Node {
    internal static func makeConfig(prioritized: [Source]) throws -> Node {
        var config = Node([:])
        try prioritized.forEach { source in
            let source = try source.makeConfig()
            config.merged(with: source).flatMap { config = $0 }
        }
        return config
    }
}

extension Source {
    fileprivate func makeConfig() throws -> Node {
        switch self {
        case let .memory(name: name, config: config):
            return .object([name: config])
        case .commandLine:
            return Node.makeCLIConfig()
        case let .directory(root: root):
            return try Node.makeConfig(directory: root)
        }
    }
}
