import PathIndexable
import Foundation

public class Localization {
    private let localizationDirectoryPath: String
    private let localization: JsonDirectory

    public init(workingDirectory: String = "./") {
        let configDirectory = workingDirectory.finish("/") + "Localization/"
        self.localizationDirectoryPath = configDirectory
        self.localization = FileManager.loadDirectory(configDirectory)
            ?? JsonDirectory(name: "empty", files: [])
    }

    public subscript(_ languageCode: String, _ paths: PathIndex...) -> String {
        return self[languageCode, paths]
    }

    public subscript(_ languageCode: String, _ paths: [PathIndex]) -> String {
        return localization[languageCode, paths]?.string
            ?? localization["default", paths]?.string
            ?? "not found" // TODO: Discuss message or ""
    }
}
