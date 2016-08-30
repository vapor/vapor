import Foundation
import JSON
import PathIndexable
import Core
import Node

public protocol KeyAccessible {
    associatedtype Key
    associatedtype Value
    subscript(key: Key) -> Value? { get set }
}

extension Dictionary: KeyAccessible {}

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
                // If something exists, and is object, merge. Else leave what's there
                guard let merged = existing.merged(with: value) else { return }
                self[key] = merged
            } else {
                self[key] = value
            }
        }
    }
}

extension Node {
    func merged(with sub: Node) -> Node? {
        guard let object = self.nodeObject, let value = sub.nodeObject else { return nil }
        var mutable = object
        mutable.merge(with: value)
        return .object(mutable)
    }
}

public enum Source {
    case memory(name: String, config: Node)
    case commandline
    case directory(root: String)
}

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
    internal func makeConfig() throws -> Node {
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

let fileManager = FileManager.default

func isDirectory(path: String) -> Bool {
    var isDirectory: ObjCBool = false
    FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
    return isDirectory.boolValue
}

func files(path: String) throws -> [String] {
    let path = path.finished(with: "/")
    let subPaths = try fileManager.subpathsOfDirectory(atPath: path)
    return subPaths.filter { !$0.contains("/") && !isDirectory(path: path + $0) && $0 != ".DS_Store" }
}

let jsonBytes = ".json".bytes
extension String {
    mutating func removedJSONSuffix() {
        guard hasSuffix(".json") else { return }
        self = self.bytes.dropLast(jsonBytes.count).string
    }
}

extension Node {
    static func makeConfig(directory: String) throws -> Node {
        let directory = directory.finished(with: "/")
        var node = Node([:])

        try files(path: directory).forEach { name in
            var name = name
            let contents = try Node.loadContents(path: directory + name)
            name.removedJSONSuffix()
            node[name] = contents.hydratedEnv()
        }

        return node
    }

    static func loadContents(path: String) throws -> Node {
        let data = try DataFile().load(path: path)
        guard path.hasSuffix(".json") else { return .bytes(data) }
        return try JSON(bytes: data).converted()
    }
}

extension Node {
    /**
        Populate values from environment that lead w/ `$`.
    */
    internal func hydratedEnv() -> Node? {
        switch self {
        case .null, .number(_), .bool(_), .bytes(_):
            return self
        case let .object(ob):
            guard !ob.isEmpty else { return self }

            var mapped = [String: Node]()
            ob.forEach { k, v in
                guard let k = k.hydratedEnv(), let v = v.hydratedEnv() else { return }
                mapped[k] = v
            }
            guard !mapped.isEmpty else { return nil }
            return .object(mapped)
        case let .array(arr):
            let mapped = arr.flatMap { $0.hydratedEnv() }
            return .array(mapped)
        case let .string(str):
            return str.hydratedEnv().flatMap(Node.string)
        }
    }
}

extension String {
    /**
        $PORT:8080
     
        Checks first if `PORT` env variable is set, then loads `8080`
    */
    internal func hydratedEnv() -> String? {
        guard hasPrefix("$") else { return self }
        let components = self.bytes
            .dropFirst()
            .split(separator: .colon, maxSplits: 1, omittingEmptySubsequences: true)
            .map({ $0.string })

        return components.first.flatMap(Env.get)
            ?? components[safe: 1]
    }
}
