import Node
import Core
import Foundation
import Configs
import JSONs

extension Config {
    public static func fromFiles(
        arguments: [String] = CommandLine.arguments,
        environment: Environment? = nil,
        at path: String? = nil
    ) throws -> Config {
        let env = environment
            ?? arguments.environment
            ?? .development

        let configDirectory = path
            ?? Config.workingDirectory(for: arguments) + "Config/"

        if !Foundation.FileManager.default.fileExists(atPath: configDirectory) {
            print("Could not load config files from: \(configDirectory)")
            print("Try using the configDir flag")
            print("ex: .build/debug/Run --configDir=/absolute/path/to/configs")
        }
        
        var sources = [Source]()
        sources.append(.commandLine(arguments: arguments))
        try sources.append(fromDirectory(configDirectory + "secrets"))
        try sources.append(fromDirectory(configDirectory + env.description))
        try sources.append(fromDirectory(configDirectory))

        var config = Config.makeConfig(prioritized: sources)
        config.environment = env
        return config
    }

    internal static func fromDirectory(_ directory: String) throws -> Source {
        let directory = directory.finished(with: "/")
        var config = Config()

        try FileManager().files(path: directory).forEach { name in
            var name = name
            let contents = try Config.loadContents(path: directory + name)
            name.removedJSONSuffix()
            config[name] = contents.environmentVariablesResolved()
        }

        return .memory(config: config)
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
    internal static func makeConfig(prioritized: [Source]) -> Config {
        var config = Config()
        prioritized.forEach { source in
            let source = source.makeConfig()
            config.merged(with: source).flatMap { config = $0 }
        }
        return config
    }
}

extension Source {
    fileprivate func makeConfig() -> Config {
        switch self {
        case .memory(let config):
            return config
        case .commandLine(let arguments):
            return Config.makeCLIConfig(arguments: arguments)
        }
    }
}


extension Config {
    /**
     Load the file at a path as raw bytes, or as parsed JSON representation
     */
    private static func loadContents(path: String) throws -> Config {
        let data = try DataFile.read(at: path)
        guard path.hasSuffix(".json") else { return .string(data.makeString()) }
        do {
            let json = try JSON(bytes: data)
            return try json.converted(to: Config.self)
        } catch {
            print("Failed to load json at path \(path)")
            print("ensure there's no syntax errors in JSON")
            throw error
        }
    }
}

/**
 Not publicizing these because there's some nuance specific to config
 */
extension FileManager {
    fileprivate func isDirectory(path: String) -> Bool {
        var isDirectory: ObjCBool = false
        _ = fileExists(atPath: path, isDirectory: &isDirectory)
        #if os(Linux)
            return isDirectory
        #else
            return isDirectory.boolValue
        #endif
    }

    fileprivate func files(path: String) throws -> [String] {
        let path = path.finished(with: "/")
        guard isDirectory(path: path) else { return [] }
        let subPaths = try subpathsOfDirectory(atPath: path)
        return subPaths.filter { !$0.contains("/") && !isDirectory(path: path + $0) && $0 != ".DS_Store" }
    }
}

/**
 Drop JSON suffix for names
 */
extension String {
    private static let jsonSuffixCount = ".json".makeBytes().count
    fileprivate mutating func removedJSONSuffix() {
        guard hasSuffix(".json") else { return }
        self = self.makeBytes().dropLast(String.jsonSuffixCount).makeString()
    }
}

