/**
    Parses and interprets configuration files
    included under Config in the working directory.

    Files stored in the Config directory can be accessed
    via `app.config.get("filename.property")`.

    For example, a file named `Config/app.json` containing
    `{"port": 80}` can be accessed with `app.config.get("app.port")`.
    To override certain configurations for a given environment,
    create a file with the same name in a subdirectory of the environment.
    For example, a file named `Config/production/app.json` would override
    any properties in `Config/app.json`.

    Finally, Vapor supports sensitive environment specific information, such
    as API keys, to be stored in a special configuration file at `Config/.env.json`.
    This file should be included in the `.gitignore` by default so that
    sensitive information does not get added to version control.
*/
public class Config {

    public enum Error: ErrorProtocol {
        case noFileFound
        case noValueFound
    }

    /**
        The internal store of configuration options
        backed by `Json`
     */
    private var seed: [String: Json]

    /**
        Creates an instance of `Config` with an
        optional starting repository of information.
        The application is required to detect environment.
    */
    public init(seed: [String: Json] = [:], application: Application? = nil) {
        self.seed = seed

        if let application = application {
            populate(application)
        }
    }

    /**
        Returns whether this instance of `Config` contains the key
     */
    public func has(_ keyPath: String) -> Bool {
        let result: Node? = try? get(keyPath)
        return result != nil
    }

    /**
        Returns the generic Json representation for an item at a given path or throws
     */
    public func get(_ keyPath: String) throws -> Node {
        var keys = keyPath.keys
        guard let json: Json = seed[keys.removeFirst()] else {
            throw Error.noFileFound
        }

        var node: Node? = json

        for key in keys {
            node = node?.object?[key]
        }

        guard let result = node else {
            throw Error.noValueFound
        }

        return result
    }

    /**
        Returns the value for a given type from the Config or throws
     */
    public func get<T: NodeInitializable>(_ keyPath: String) throws -> T {
        let result: Node = try get(keyPath)
        return try T.make(with: result)
    }


    /**
        Returns the result of `get(key: String)` but with a `String` fallback for `nil` cases
     */
    public func get<T: NodeInitializable>(_ keyPath: String, _ fallback: T) -> T {
        let string: T? = try? get(keyPath)
        return string ?? fallback
    }


    /**
        Temporarily sets a value for a given key path
     */
    public func set(_ value: Json, forKeyPath keyPath: String) {
        var keys = keyPath.keys
        let group = keys.removeFirst()

        if keys.count == 0 {
            seed[group] = value
        } else {
            seed[group]?.set(value, keys: keyPath.keys)
        }
    }

    /**
        Calls populate() in a convenient non-throwing manner
     */
    public func populate(_ application: Application) -> Bool {
        let configDir = application.workDir + "Config"

        if FileManager.fileAtPath(configDir).exists {
            do {
                try populate(configDir, application: application)
                return true
            } catch {
                Log.error("Unable to populate config: \(error)")
                return false
            }
        } else {
            return false
        }
    }


    /**
        Attempts to populate the internal configuration store
     */
    public func populate(_ path: String, application: Application) throws {
        var path = path.finish("/")
        var files = [String: [String]]()

        // Populate config files by environment
        try populateConfigFiles(&files, in: path)

        for env in application.environment.description.keys {
            path += env + "/"

            if FileManager.fileAtPath(path).exists {
                try populateConfigFiles(&files, in: path)
            }
        }

        // Loop through files and merge config upwards so the
        // environment always overrides the base config
        //
        //
        // The isEmpty check is a workaround for the Linux system and is necessary until
        // an alternative solution is fixed, or it's confirmed appropriate
        // This is duplicated below in `populateConfigFiles`. just doubling down.
        for (group, files) in files where !group.isEmpty {
            if group == ".env" {
                // .env is handled differently below
                continue
            }

            for file in files {
                let bytes = try FileManager.readBytesFromFile(file)
                let json = try Json(Data(bytes))

                if seed[group] == nil {
                    seed[group] = json
                } else {
                    seed[group]?.merge(with: json)
                }
            }
        }

        // Apply .env overrides, which is a single file
        // containing multiple groups
        if let env = files[".env"] {
            for file in env {
                let bytes = try FileManager.readBytesFromFile(file)
                let json = try Json(Data(bytes))

                guard case .object(let object) = json else {
                    return
                }

                for (group, json) in object {
                    if seed[group] == nil {
                        seed[group] = json
                    } else {
                        seed[group]?.merge(with: json)
                    }
                }
            }
        }
    }

    private func populateConfigFiles(_ files: inout [String: [String]], in path: String) throws {
        let contents = try FileManager.contentsOfDirectory(path)

        for file in contents {
            //
            //
            // The isEmpty check is a workaround for the Linux system and is necessary until
            // an alternative solution is fixed, or it's confirmed appropriate
            // This is duplicated above. just doubling down.
            guard let fileName = file.split(byString: "/").last where !fileName.isEmpty else {
                continue
            }

            let name: String

            if fileName == ".env.json" {
                name = ".env"
            } else if fileName.hasSuffix(".json"), let value = fileName.split(byString: ".").first {
                name = value
            } else {
                continue
            }

            if files[name] == nil {
                files[name] = []
            }

            files[name]?.append(file)
        }
    }

}

extension Json {

    private mutating func set(_ value: Json, keys: [Swift.String]) {
        var keys = keys

        guard keys.count > 0 else {
            return
        }

        let key = keys.removeFirst()

        guard case .object(let object) = self else {
            return
        }

        var updated = object

        if keys.count == 0 {
            updated[key] = value
        } else {
            var child = updated[key] ?? Json.object([:])
            child.set(value, keys: keys)
        }
    }

}


extension String {

    private var keys: [String] {
        return split(byString: ".")
    }

}
