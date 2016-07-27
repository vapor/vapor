import Foundation
import JSON
import PathIndexable

extension ProcessInfo {
    static func arguments() -> [String] {
        #if !os(Linux)
            return ProcessInfo.processInfo.arguments
        #else
            return ProcessInfo.processInfo().arguments
        #endif
    }
}

private struct PrioritizedDirectoryQueue {
    let directories: [JSONDirectory]

    subscript(_ fileName: String, indexes: [PathIndex]) -> JSON? {
        return directories
            .lazy
            .flatMap { directory in return directory[fileName, indexes] }
            .first
    }
}

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
        seed: JSON = [:],
        workingDirectory: String = "./",
        environment: Environment? = nil,
        arguments: [String] = ProcessInfo.arguments()
    ) throws {
        let configDirectory = workingDirectory.finished(with: "/") + "Config/"
        self.environment = environment ?? Environment.loader(arguments: arguments)

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
        self.environment = Environment.loader(arguments: ProcessInfo.arguments())
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
    static var loader: (arguments: [String]) -> Environment = { arguments in
        if let env = arguments.value(for: "env").flatMap(Environment.init(id:)) {
            return env
        } else {
            return .development
        }
    }
}


extension String {
    private var keyPathComponents: [String] {
        return components(separatedBy: ".")
    }

}
