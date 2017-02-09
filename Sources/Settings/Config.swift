@_exported import Node

public struct Config: NodeBacked {
    public var node: Node

    public init(_ node: Node) {
        self.node = node.hydratedEnv() ?? node
    }

    public init(prioritized: [Source]) throws {
        self.node = try Node.makeConfig(prioritized: prioritized)
    }
}

public enum ConfigError: Error {
    case unsupported(value: String, key: [String], file: String)
    case missing(key: [String], file: String, desiredType: Any.Type)
    case unknown(Error)
}

extension ConfigError: CustomStringConvertible {
    public var description: String {
        let reason: String

        switch self {
        case .unsupported(let value, let key, let file):
            let keyPath = key.joined(separator: ".")
            reason = "Unsupported value `\(value)` for key `\(keyPath)` in `Config/\(file).json`"
        case .missing(let key, let file, let desiredType):
            let keyPath = key.joined(separator: ".")
            reason = "Key `\(keyPath)` in `Config/\(file).json` of type \(desiredType) required."
        case .unknown(let error):
            reason = "\(error)"
        }

        return "Configuration error: \(reason)"
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

extension Config: Equatable {}
public func == (lhs: Config, rhs: Config) -> Bool {
    return lhs.node == rhs.node
}
