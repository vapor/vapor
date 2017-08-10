import Node
import Core
import Foundation
import Configs

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

        if !Foundation.FileManager.default.fileExists(atPath: configDirectory) {
            print("Could not load config files from: \(configDirectory)")
            print("Try using the configDir flag")
            print("ex: .build/debug/Run --configDir=/absolute/path/to/configs")
        }
        
        var sources = [Source]()
        sources.append(.commandLine)
        sources.append(.directory(root: configDirectory + "secrets"))
        sources.append(.directory(root: configDirectory + env.description))
        sources.append(.directory(root: configDirectory))

        return try Config.makeConfig(prioritized: sources)
    }
}

import Mapper
extension StructuredData: MapRepresentable {
    public func makeMap() throws -> Map {
        switch self {
        case .array(let array):
            return try .array(array.map { try $0.makeMap() })
        case .bool(let bool):
            return  .bool(bool)
        case .bytes(let bytes):
            return  .string(bytes.makeString())
        case .date(let date):
            return .double(date.timeIntervalSince1970)
        case .null:
            return .null
        case .number(let num):
            switch num {
            case .double(let double):
                return .double(double)
            case .int(let int):
                return .int(int)
            case .uint(let uint):
                return .string(uint.description)
            }
        case .object(let obj):
            return try .dictionary(obj.mapValues { try $0.makeMap() })
        case .string(let string):
            return .string(string)
        }
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

extension Config {
    internal static func makeConfig(prioritized: [Source]) throws -> Config {
        var config = Config()
        try prioritized.forEach { source in
            let source = try source.makeConfig()
            config.merged(with: source).flatMap { config = $0 }
        }
        return config
    }
}

extension Source {
    fileprivate func makeConfig() throws -> Config {
        switch self {
        case let .memory(name: name, config: config):
            return .dictionary([name: config])
        case .commandLine:
            return Config.makeCLIConfig()
        case let .directory(root: root):
            return try Config.makeConfig(directory: root)
        }
    }
}
