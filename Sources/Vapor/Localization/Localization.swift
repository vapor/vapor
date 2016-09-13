import Foundation
import Core
import PathIndexable

public class Localization {
    private let localizations: [String: Node]
    private let defaultDialect: String
    
    public convenience init(localizationDirectory: String) throws {
        // Finish path with "/"
        let localizationDirectory = localizationDirectory.finished(with: "/")
        
        // List the files in the directory
        let contents = try FileManager.contentsOfDirectory(localizationDirectory)
        
        // Read the files into nodes mapped to their appropriate language
        var localizations = [String: Node]()
        for path in contents where path.hasSuffix(".json") {
            // Get the name
            guard let nameRaw = path.components(separatedBy: "/").last?.characters.split(separator: ".").first else {
                continue
            }
            let name = String(nameRaw)
            
            // Read the
            let data = try DataFile().load(path: path)
            localizations[name] = try JSON(bytes: data).makeNode()
        }
        
        self.init(localizations: localizations)
    }

    public init(localizations: [String: Node]? = nil, defaultLocale: String? = nil) {
        self.localizations = localizations ?? [:]
        self.defaultDialect = defaultLocale ?? localizations?.keys.first ?? "default"
    }

    public subscript(_ languageCode: String, _ paths: PathIndex...) -> String {
        return self[languageCode, paths]
    }

    public subscript(_ languageCode: String, _ paths: [PathIndex]) -> String {
        return localizations[languageCode]?[paths]?.string  // Index by language
            ?? localizations[defaultDialect]?[paths]?.string // Index the default language
            ?? paths.map { "\($0)" }.joined(separator: ".") // Return the literal path indexed if no translation
    }
}
