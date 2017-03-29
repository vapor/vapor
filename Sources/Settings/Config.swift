@_exported import Node

public struct Config: StructuredDataWrapper {
    public var wrapped: StructuredData
    public let context: Context

    public init(_ wrapped: StructuredData, in context: Context?) {
        self.wrapped = wrapped.hydratedEnv() ?? StructuredData([:])
        self.context = context ?? emptyContext
    }

    public init(prioritized: [Source]) throws {
        let node = try Node.makeConfig(prioritized: prioritized)
        self.init(node: node)
    }
}

extension Config {
    public static func `default`(withEnv env: String? = nil) throws -> Config {
        let configDirectory = workingDirectory() + "Config/"
        var sources = [Source]()
        sources.append(.commandLine)
        sources.append(.directory(root: configDirectory + "secrets"))
        if let env = env {
            sources.append(.directory(root: configDirectory + env))
        }
        sources.append(.directory(root: configDirectory))

        return try Config(prioritized: sources)
    }

    static func workingDirectory() -> String {
        #if swift(>=3.1)
            let parts = #file.components(separatedBy: "/.build")
        #else
            let parts = #file.components(separatedBy: "/Packages/")
        #endif
        return parts.first?.finished(with: "/") ?? "./"
    }
}

/// Typical errors that may happen
/// during the parsing of Vapor json
/// configuration files.
public enum ConfigError: Error {
    case unsupported(value: String, key: [String], file: String)
    case missing(key: [String], file: String, desiredType: Any.Type)
    case missingFile(String)
    case unspecified(Error)
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
        case .missingFile(let file):
            reason = "`Config/\(file).json` required."
        case .unspecified(let error):
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
