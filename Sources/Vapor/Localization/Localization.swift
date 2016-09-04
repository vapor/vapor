import PathIndexable
import Foundation

public class Localization {
    private let localization: JSONDirectory

    public convenience init(workingDirectory: String) throws {
        let configDirectory = workingDirectory.finished(with: "/") + "Localization/"
        let localization = try FileManager.loadDirectory(configDirectory)
        self.init(jsonDirectory: localization)
    }

    init(jsonDirectory: JSONDirectory? = nil) {
        localization = jsonDirectory ?? JSONDirectory(name: "empty", files: [])
    }

    public subscript(_ languageCode: String, _ paths: PathIndex...) -> String {
        return self[languageCode, paths]
    }

    public subscript(_ languageCode: String, _ paths: [PathIndex]) -> String {
        return localization[languageCode, paths]?.string
            ?? localization["default", paths]?.string
            ?? paths.map { "\($0)" }.joined(separator: ".")
    }
}
