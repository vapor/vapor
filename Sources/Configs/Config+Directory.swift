import Core
import Foundation
import JSON

extension Node {
    /**
        Load all files in a given directory as config files.
     
        - warning: will ignore all subdirectories.
        - parameter directory: the root path to the directory. 
    */
    internal static func makeConfig(directory: String) throws -> Node {
        let directory = directory.finished(with: "/")
        var node = Node([:])

        try FileManager.default.files(path: directory).forEach { name in
            var name = name
            let contents = try Node.loadContents(path: directory + name)
            name.removedJSONSuffix()
            node[name] = contents.hydratedEnv()
        }

        return node
    }

    /**
        Load the file at a path as raw bytes, or as parsed JSON representation
    */
    private static func loadContents(path: String) throws -> Node {
        let data = try DataFile.read(at: path)
        guard path.hasSuffix(".json") else { return .bytes(data) }
        do {
            let json = try JSON(bytes: data)
            return json.converted()
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
        #if os(Linux) && !swift(=>4.1)
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
