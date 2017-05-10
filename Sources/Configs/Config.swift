@_exported import Node
import Core
import Foundation

public final class Config: StructuredDataWrapper {
    public var wrapped: StructuredData
    public var context: Context
    
    /// The arguments passed to theConfig
    public var arguments: [String]
    
    /// The current droplet environment
    public var environment: Environment
    
    /// For building onto the Config object
    public var storage: [String: Any]

    public init(_ wrapped: StructuredData, in context: Context?) {
        self.wrapped = wrapped.hydratedEnv() ?? StructuredData([:])
        self.context = context ?? emptyContext
        self.arguments = []
        self.environment = .development
        self.storage = [:]
    }

    public init(
        prioritized: [Source],
        arguments: [String] = CommandLine.arguments,
        environment: Environment = .development
    ) throws {
        let node = try Node.makeConfig(prioritized: prioritized)
        self.wrapped = node.wrapped
        self.context = emptyContext
        self.arguments = arguments
        self.environment = environment
        self.storage = [:]
    }
}

extension Config {
    public convenience init(
        arguments: [String] = CommandLine.arguments
    ) throws {
        let env = arguments.environment ?? .development

        let configDirectory = Config.workingDirectory(for: arguments) + "Config/"

        if !FileManager.default.fileExists(atPath: configDirectory) {
            print("Could not load config files from: \(configDirectory)")
            print("Try using the configDir flag")
            print("ex: .build/debug/Run --configDir=/absolute/path/to/configs")
        }
        
        var sources = [Source]()
        sources.append(.commandLine)
        sources.append(.directory(root: configDirectory + "secrets"))
        sources.append(.directory(root: configDirectory + env.description))
        sources.append(.directory(root: configDirectory))
        
        try self.init(
            prioritized: sources,
            arguments: arguments,
            environment: env
        )
    }
}

extension Config {
    public static func workingDirectory(
        for arguments: [String] = CommandLine.arguments
    ) -> String {
        let workDir = arguments.value(for: "workdir")
            ?? arguments.value(for: "workDir")
            ?? arguments.value(for: "configDir")
            ?? arguments.value(for: "configdir")
            ?? Core.workingDirectory()
        
        return workDir.finished(with: "/")
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
