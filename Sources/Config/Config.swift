import Foundation
import JSON
import PathIndexable
import Core

public protocol KeyAccessible {
    associatedtype Key
    associatedtype Value
    subscript(key: Key) -> Value? { get set }
}

extension Dictionary: KeyAccessible {}


import Node
extension Node {
    public static func merge(prioritized: [(name: String, node: Node)]) -> Node {
        var result = [String: Node]()
        prioritized.forEach { name, node in result.merge(with: [name: node]) }
        return .object(result)
    }
}

extension KeyAccessible where Key == String, Value == Node {
    mutating func merge(with sub: [String: Node]) {
        sub.forEach { key, value in
            if let existing = self[key] {
                // If something exists, and is object, merge. Else leave
                guard let object = existing.nodeObject, let value = value.nodeObject else { return }
                var mutable = object
                mutable.merge(with: value)
                self[key] = .object(mutable)
            } else {
                self[key] = value
            }
        }
    }
}

public final class ConfigLoader {
    public enum Source {
        case memory(name: String, config: Node)
        case commandline
        case directory(root: String, environment: String?)
    }

    public let prioritized: [Source]

    public init(prioritized: [Source] = [.commandline, .directory(root: "./", environment: nil)]) {
        self.prioritized = prioritized
    }

    func makeConfig() throws -> Node {
        return [:]
    }
}

extension ConfigLoader.Source {
    func makeConfig() throws -> Node {
        switch self {
        case let .memory(name: name, config: config):
            return .object([name: config])
        case let .commandline:
            return Node.makeCLIConfig()
        case let .directory(root: root, environment: environment):
            fatalError()
        }
    }
}

let fileManager = FileManager.default

func isDirectory(path: String) -> Bool {
    var isDirectory: ObjCBool = false
    FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
    return isDirectory.boolValue
}

func files(path: String) throws -> [String] {
    let subPaths = try fileManager.subpathsOfDirectory(atPath: path)
    return subPaths.filter { !$0.contains("/") && !isDirectory(path: $0) && $0 != ".DS_Store" }
}

extension String {
    func removedTailIfExists(tail: String) -> String {
        guard hasSuffix(tail) else { return self }
        return bytes.dropLast(tail.bytes.count).string
    }
}

extension Node {
    static func make(directory: String) throws -> Node {
        let directory = directory.finished(with: "/")
        var node = Node([:])
        let names = try files(path: directory).forEach { name in
            let contents = try Node.loadContents(path: directory + name)
            if name.hasSuffix(".json") {
                name.bytes.dropLast(".json".bytes.count).string
            }
            return bytes.dropLast(tail.bytes.count).string
            return (name, contents)
        }

        return node
    }

    static func loadContents(path: String) throws -> Node {
        let data = try DataFile().load(path: path)
        guard path.hasSuffix(".json") else { return .bytes(data) }
        return try JSON(bytes: data).converted()
    }

/*
        guard let directoryName = path.components(separatedBy: "/").last else {
            return nil
        }

            guard let contents = try? FileManager.contentsOfDirectory(path) else { return nil }

            var jsonFiles: [JSONFile] = []
            for file in contents where file.hasSuffix(".json") {
                guard let name = file.components(separatedBy: "/").last else {
                    continue
                }

                let json = try loadJson(file)

                let jsonFile = JSONFile(name: name, json: json)
                jsonFiles.append(jsonFile)
            }

            let directory = JSONDirectory(name: directoryName, files: jsonFiles)
            return directory
        }
*/
}

/*
private static func loadJson(_ path: String) throws -> JSON {
    let bytes = try FileManager.readBytesFromFile(path)
    return try JSON(bytes: bytes)
}
}
 */

/**

 */


/*
private struct PrioritizedDirectoryQueue {
    let directories: [JSONDirectory]

    subscript(_ fileName: String, indexes: [PathIndex]) -> JSON? {
        return directories
            .lazy
            .flatMap { directory in return directory[fileName, indexes] }
            .first
    }
}

/*
public class Config {
    enum Data {
        case folder(root: String, prioritizedSubDirectories: [String])
        case commandLine
        case memory(Node)
    }


}
*/
/**
    Parses and interprets configuration files
    included under Config in the working directory.

    Files stored in the Config directory can be accessed
    via `drop.config["filename", "property"]`.

    For example, a file named `Config/drop.json` containing
    `{"port": 80}` can be accessed with `drop.config["app" "port"].int`.
    To override certain configurations for a given environment,
    create a file with the same name in a subdirectory of the environment.
    For example, a file named `Config/production/drop.json` would override
    any properties in `Config/drop.json` when the drop is in production mode.

    Finally, Vapor supports sensitive environment specific information, such
    as API keys, to be stored in a special configuration folder at `Config/secrets`.
    This folder should be included in the `.gitignore` by default so that
    sensitive information does not get added to version control.
*/
public class Config {

    /**
        The environment loaded from `Environment.loader
    */
    public let environment: Environment
    private let directoryQueue: PrioritizedDirectoryQueue

    /**
        Creates an instance of `Config` with
        starting configurations.
        The droplet is required to detect environment.
    */
    public init(
        seed: JSON = JSON(),
        workingDirectory: String = "./",
        environment: Environment? = nil,
        arguments: [String] = CommandLine.arguments
    ) throws {
        let configDirectory = workingDirectory.finished(with: "/") + "Config/"
        self.environment = environment ?? Environment.loader(arguments)

        let seedFile = JSONFile(name: "app", json: seed)
        let seedDirectory = JSONDirectory(name: "seed-data", files: [seedFile])
        var prioritizedDirectories: [JSONDirectory] = [seedDirectory]

        // command line args passed w/ following syntax loaded first after seed
        // --config:drop.port=9090
        // --config:passwords.mongo-user=user
        // --config:passwords.mongo-password=password
        // --config:<name>.<path>.<to>.<value>=<actual-value>
        let cliDirectory = Config.makeCLIConfig(arguments: arguments)
        prioritizedDirectories.insert(cliDirectory, at: 0) // should be most important

        // Json files are loaded in order of priority
        // it will go like this
        // paths will be searched for in top down order
        if let directory = try FileManager.loadDirectory(configDirectory + "secrets") {
            prioritizedDirectories.append(directory)
        }
        if let directory = try FileManager.loadDirectory(configDirectory + self.environment.description) {
            prioritizedDirectories.append(directory)
        }
        if let directory = try FileManager.loadDirectory(configDirectory) {
            prioritizedDirectories.append(directory)
        }

        directoryQueue = PrioritizedDirectoryQueue(directories: prioritizedDirectories)
    }

    public init() {
        self.environment = Environment.loader(CommandLine.arguments)
        self.directoryQueue = PrioritizedDirectoryQueue(directories: [])
    }

    /**
         Use this to access config keys for specified file.
         For example, if I have a config file named 'metadata.json'
         that looks like this:

             {
                 "info" : {
                     "port" : 9090
                 }
             }

         You would access the port like this:

             let port = drop.config["metadata", "info", "por"].int ?? 8080

         Follows format

             config[<json-file-name>, <path>, <to>, <value>

         - parameter file:  name of json file to look for
         - parameter paths: path to key

         - returns: value if it exists.
     */
    public subscript(_ file: String, _ paths: PathIndex...) -> Polymorphic? {
        return self[file, paths]
    }

    /**
         Splatting so that variadic can pass through here

         - parameter file:  name of json file to look for
         - parameter paths: path to key

         - returns: value if it exists.
     */
    public subscript(_ file: String, _ paths: [PathIndex]) -> Polymorphic? {
        let value = directoryQueue[file, paths]

        // check if value exists in Env
        if let string = value?.string, string.characters.first == "$" {
            let name = String(string.characters.dropFirst())
            return Env.get(name) // will return nil if env variable not found
        }

        return value
    }
}

extension Environment {
    /**
        Used to load Environment automatically. Defaults to looking for `env` command line argument
     */
    static var loader: ([String]) -> Environment = { arguments in
        if let env = arguments.value(for: "env").flatMap(Environment.init(id:)) {
            return env
        } else {
            return .development
        }
    }
}

extension Sequence where Iterator.Element == String {
    func value(for string: String) -> String? {
        for item in self {
            let search = "--\(string)="
            if item.hasPrefix(search) {
                return item.components(separatedBy: search).joined(separator: "")
            }
        }

        return nil
    }
}

extension String {
    private var keyPathComponents: [String] {
        return components(separatedBy: ".")
    }

}
*/
