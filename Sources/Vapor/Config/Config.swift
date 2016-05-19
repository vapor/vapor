import PathIndexable

private struct JsonFile {
    let name: String
    let json: Json
}

private struct ConfigDirectory {
    let name: String
    let files: [JsonFile]

    subscript(_ name: String, _ paths: [PathIndex]) -> Json? {
        return files
            .lazy
            .filter { file in
                return file.name == name + ".json"
            }
            .flatMap { file in file.json[paths] }
            .first
    }
}

private struct PrioritizedDirectoryQueue {
    let directories: [ConfigDirectory]

    subscript(_ fileName: String, indexes: [PathIndex]) -> Json? {
        return directories
            .lazy
            .flatMap { directory in return directory[fileName, indexes] }
            .first
    }
}

extension FileManager {
    private static func loadDirectory(_ path: String) -> ConfigDirectory? {
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

        let directory = ConfigDirectory(name: directoryName, files: jsonFiles)
        return directory
    }

    private static func loadJson(_ path: String) throws -> Json {
        let bytes = try FileManager.readBytesFromFile(path)
        return try Json.deserialize(bytes)
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
    any properties in `Config/app.json`.

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
    public init(seed configurations: [String: Json] = [:], workingDirectory: String = "./", environment: Environment = .loader()) {
        let configDirectory = workingDirectory.finish("/") + "Config/"
        self.configDirectory = configDirectory
        self.environment = environment


        let files = configurations.map { name, json in return JsonFile(name: name, json: json) }
        let seedDirectory = ConfigDirectory(name: "seed-data", files: files)
        var prioritizedDirectories: [ConfigDirectory] = [seedDirectory]

        //
        // TODO: cli will possibly be first in priority queue in future
        // potential syntax
        // --config:app.port=9090
        // --config:passwords.mongo-user=user
        // --config:passwords.mongo-password=password
        // --config:<name>.<path>.<to>.<value>=<actual-value>

        // Json files are loaded in order of priority
        // it will go like this
        // paths will be searched for in top down order
        if let directory = FileManager.loadDirectory(configDirectory + "secrets") {
            //print("Secrets: \(directory)")
            prioritizedDirectories.append(directory)
        }
        //print("Env: \(environment.description)")
        if let directory = FileManager.loadDirectory(configDirectory + environment.description) {
            //print("Enf: \(directory)")
            prioritizedDirectories.append(directory)
        }
        if let directory = FileManager.loadDirectory(configDirectory) {
            //print("Config directory: \(directory)")
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
    public subscript(_ file: String, _ paths: PathIndex...) -> Node? {
        return self[file, paths]
    }

    /**
         Splatting so that variadic can pass through here

         - parameter file:  name of json file to look for
         - parameter paths: path to key

         - returns: value if it exists.
     */
    public subscript(_ file: String, _ paths: [PathIndex]) -> Node? {
        return directoryQueue[file, paths]
    }

    /**
         Returns whether this instance of `Config` contains the path
     */
    public func has(_ path: String, _ indexes: PathIndex...) -> Bool {
        return self[path, indexes] != nil
    }
}

extension Environment {
    /**
        Used to load Environment automatically. Defaults to looking for `env` command line argument
     */
    static var loader: Void -> Environment = {
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
