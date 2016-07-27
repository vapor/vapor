import Foundation

extension Config {
    static func makeCLIConfig(arguments: [String]) -> JSONDirectory {
        let configArgs = arguments.filter { $0.hasPrefix("--") }

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

        let jsonFiles = directory.map { fileName, json in JSONFile(name: fileName, json: json) }
        let config = JSONDirectory(name: "cli", files: jsonFiles)
        return config
    }

    static func parseArgument(_ arg: String) -> (key: String, value: String)? {
        let info = arg
            .characters
            .split(separator: "=",
                   maxSplits: 1,
                   omittingEmptySubsequences: true)
            .map(String.init)

        if info.count == 1, let key = info.first {
            // Keys like --release default to `release = true`
            return (key, "true")
        } else if info.count == 2, let key = info.first, let value = info.last {
            return (key, value)
        } else {
            return nil
        }
    }

    static func parseConfigKey(_ key: String) -> (file: String, path: [PathIndex])? {
        if key.hasPrefix("--config:") {
            return parseComplexConfigKey(key)
        } else {
            return parseSimpleConfigKey(key)
        }
    }

    private static func parseComplexConfigKey(_ key: String) -> (file: String, path: [PathIndex])? {
        // --config:drop.port
        // expect [--config, drop.port]
        let paths = key
            .characters
            .split(separator: ":",
                   maxSplits: 1,
                   omittingEmptySubsequences: true)
            .map(String.init)

        guard
            paths.count == 2,
            var keyPaths = paths.last?.components(separatedBy: "."),
            let fileName = keyPaths.first,
            // first argument is file name, subsequent args are actual path
            //
            keyPaths.count > 1
            else {
                return nil
        }

        // first argument is file name, subsequent arguments are paths
        keyPaths.remove(at: 0)

        return (fileName, keyPaths.map { $0 as PathIndex })
    }

    private static func parseSimpleConfigKey(_ key: String) -> (file: String, path: [PathIndex])? {
        // --key.path.to.automate
        guard
            let path = key
                .components(separatedBy: "--")
                .last?
                .components(separatedBy: ".")
            else { return nil }

        return ("app", path.map { $0 as PathIndex })
    }
}
