import PathIndexable
import Foundation

internal struct JsonFile {
    let name: String
    let json: JSON

    private static let suffix = ".json"

    init(name: String, json: JSON) {
        if
            let nameSequence = name.characters.split(separator: ".").first
            where name.hasSuffix(JsonFile.suffix)
        {
            self.name = String(nameSequence)
        } else {
            self.name = name
        }
        self.json = json
    }
}

internal struct JsonDirectory {
    let name: String
    let files: [JsonFile]

    subscript(_ fileName: String, _ paths: [PathIndex]) -> JSON? {
        return files
            .lazy
            .filter { file in
                file.name == fileName
            }
            .flatMap { file in file.json[paths] }
            .first
    }
}

private struct PrioritizedDirectoryQueue {
    let directories: [JsonDirectory]

    subscript(_ fileName: String, indexes: [PathIndex]) -> JSON? {
        return directories
            .lazy
            .flatMap { directory in return directory[fileName, indexes] }
            .first
    }
}

extension FileManager {
    internal static func loadDirectory(_ path: String) -> JsonDirectory? {
        guard let directoryName = path.components(separatedBy: "/").last else {
            return nil
        }
        guard let contents = try? FileManager.contentsOfDirectory(path) else {
            return nil
        }

        var jsonFiles: [JsonFile] = []
        for file in contents where file.hasSuffix(".json") {
            guard let name = file.components(separatedBy: "/").last else {
                continue
            }
            guard let json = try? loadJson(file) else {
                continue
            }

            let jsonFile = JsonFile(name: name, json: json)
            jsonFiles.append(jsonFile)
        }

        let directory = JsonDirectory(name: directoryName, files: jsonFiles)
        return directory
    }

    private static func loadJson(_ path: String) throws -> JSON {
        let bytes = try FileManager.readBytesFromFile(path)
        return try JSON.deserialize(bytes)
    }
}

extension Process {
    private static func makeCLIConfig() -> JsonDirectory {
        let configArgs = NSProcessInfo.processInfo().arguments.filter { $0.hasPrefix("--config:") }

        // [FileName: Json]
        var directory: [String: JSON] = [:]

        for arg in configArgs {
            guard let (key, value) = parseArgument(arg) else {
                continue
            }

            guard let (file, path) = parseConfigKey(key) else {
                continue
            }

            var js = directory[file] ?? .object([:])
            js[path] = .string(value)
            directory[file] = js
        }

        let jsonFiles = directory.map { fileName, json in JsonFile(name: fileName, json: json) }
        let config = JsonDirectory(name: "cli", files: jsonFiles)
        return config
    }

    private static func parseArgument(_ arg: String) -> (key: String, value: String)? {
        let info = arg
            .characters
            .split(separator: "=",
                   maxSplits: 1,
                   omittingEmptySubsequences: true)
            .map(String.init)

        guard info.count == 2, let key = info.first, let value = info.last else {
            Log.info("Unable to parse possible config argument: \(arg)")
            return nil
        }

        return (key, value)
    }

    private static func parseConfigKey(_ key: String) -> (file: String, path: [PathIndex])? {
        // --config:app.port
        // expect [--config, app.port]
        let paths = key
            .characters
            .split(separator: ":",
                   maxSplits: 1,
                   omittingEmptySubsequences: true)
            .map(String.init)

        guard
            paths.count == 2,
            var keyPaths = paths.last?.components(separatedBy: "."),
            let fileName = keyPaths.first
            // first argument is file name, subsequent args are actual path
            //
            where keyPaths.count > 1
            else {
                Log.info("Unable to parse possible config path: \(key)")
                return nil
            }

        // first argument is file name, subsequent arguments are paths
        keyPaths.remove(at: 0)

        return (fileName, keyPaths.map { $0 as PathIndex })
    }
}

/**
    Parses and interprets configuration files
    included under Config in the working directory.

    Files stored in the Config directory can be accessed
    via `app.config["filename", "property"]`.

    For example, a file named `Config/app.json` containing
    `{"port": 80}` can be accessed with `app.config["app" "port"].int`.
    To override certain configurations for a given environment,
    create a file with the same name in a subdirectory of the environment.
    For example, a file named `Config/production/app.json` would override
    any properties in `Config/app.json` when the app is in production mode.

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

    private let configDirectory: String
    private let directoryQueue: PrioritizedDirectoryQueue

    /**
        Creates an instance of `Config` with
        starting configurations.
        The application is required to detect environment.
    */
    public init(seed configurations: [String: JSON] = [:], workingDirectory: String = "./", environment: Environment = .loader()) {
        let configDirectory = workingDirectory.finish("/") + "Config/"
        self.configDirectory = configDirectory
        self.environment = environment


        let files = configurations.map { name, json in return JsonFile(name: name, json: json) }
        let seedDirectory = JsonDirectory(name: "seed-data", files: files)
        var prioritizedDirectories: [JsonDirectory] = [seedDirectory]

        // command line args passed w/ following syntax loaded first after seed
        // --config:app.port=9090
        // --config:passwords.mongo-user=user
        // --config:passwords.mongo-password=password
        // --config:<name>.<path>.<to>.<value>=<actual-value>
        let cliDirectory = Process.makeCLIConfig()
        prioritizedDirectories.append(cliDirectory)

        // Json files are loaded in order of priority
        // it will go like this
        // paths will be searched for in top down order
        if let directory = FileManager.loadDirectory(configDirectory + "secrets") {
            prioritizedDirectories.append(directory)
        }
        if let directory = FileManager.loadDirectory(configDirectory + environment.description) {
            prioritizedDirectories.append(directory)
        }
        if let directory = FileManager.loadDirectory(configDirectory) {
            prioritizedDirectories.append(directory)
        }

        directoryQueue = PrioritizedDirectoryQueue(directories: prioritizedDirectories)
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

             let port = app.config["metadata", "info", "por"].int ?? 8080

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
        return directoryQueue[file, paths]
    }
}

extension Environment {
    /**
        Used to load Environment automatically. Defaults to looking for `env` command line argument
     */
    static var loader: (Void) -> Environment = {
        if let env = Process.valueFor(argument: "env").flatMap(Environment.init(id:)) {
            Log.info("Environment override: \(env)")
            return env
        } else {
            return .development
        }
    }
}


extension String {
    private var keyPathComponents: [String] {
        return split(byString: ".")
    }

}
