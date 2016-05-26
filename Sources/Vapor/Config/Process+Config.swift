import Foundation

extension Process {
    static func makeCLIConfig() -> JSONDirectory {
        let configArgs = NSProcessInfo.processInfo().arguments.filter { $0.hasPrefix("--") }

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

        guard info.count == 2, let key = info.first, let value = info.last else {
            Log.info("Unable to parse possible config argument: \(arg)")
            return nil
        }

        return (key, value)
    }

    static func parseConfigKey(_ key: String) -> (file: String, path: [PathIndex])? {
        if key.hasPrefix("--config:") {
            return parseComplexConfigKey(key)
        } else {
            return parseSimpleConfigKey(key)
        }
    }

    private static func parseComplexConfigKey(_ key: String) -> (file: String, path: [PathIndex])? {
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
