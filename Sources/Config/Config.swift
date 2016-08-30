@_exported import Node

extension Node {
    public static func makeConfig(prioritized: [Source]) throws -> Node {
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
        case .commandline:
            return Node.makeCLIConfig()
        case let .directory(root: root):
            return try Node.makeConfig(directory: root)
        }
    }
}
