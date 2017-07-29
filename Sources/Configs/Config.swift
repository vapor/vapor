@_exported import Node
import Core
import Foundation

public struct Config: StructuredDataWrapper {
    public var wrapped: StructuredData
    public var context: Context
    
    /// The arguments passed to theConfig
    public var arguments: [String]
    
    /// The current droplet environment
    public var environment: Environment

    public init(_ wrapped: StructuredData, in context: Context?) {
        self.wrapped = wrapped.hydratedEnv() ?? StructuredData([:])
        self.context = context ?? emptyContext
        self.arguments = []
        self.environment = .development
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
    }
}

extension Config {
    public init() {
        self.init([:])
    }
}

extension Config {
    public static func fromFiles(
        arguments: [String] = CommandLine.arguments,
        environment: Environment? = nil,
        absoluteDirectory: String? = nil
    ) throws -> Config {
        let env = environment
            ?? arguments.environment
            ?? .development

        let configDirectory = absoluteDirectory
            ?? Config.workingDirectory(for: arguments) + "Config/"

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
        
        return try Config(
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
