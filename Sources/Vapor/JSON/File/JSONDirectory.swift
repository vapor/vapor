struct JSONDirectory {
    let name: String
    let files: [JSONFile]

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

extension FileManager {
    internal static func loadDirectory(_ path: String) throws -> JSONDirectory? {
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

    private static func loadJson(_ path: String) throws -> JSON {
        let bytes = try FileManager.readBytesFromFile(path)
        return try JSON(bytes: bytes)
    }
}
