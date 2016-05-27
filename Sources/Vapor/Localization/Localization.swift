import PathIndexable
import Foundation

public class Localization {
    private let localizationDirectoryPath: String
    private let localization: JSONDirectory

    public init(workingDirectory: String = "./") {
        let configDirectory = workingDirectory.finish("/") + "Localization/"
        self.localizationDirectoryPath = configDirectory
        self.localization = FileManager.loadDirectory(configDirectory)
            ?? JSONDirectory(name: "empty", files: [])
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
