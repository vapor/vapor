import Foundation
import Core
import PathIndexable

public class Localization {
    fileprivate let localizations: [String: Node]
    fileprivate let defaultDialect: String
    
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
            localizations[name.lowercased()] = try JSON(bytes: data).converted()
        }
        
        self.init(localizations: localizations)
    }

    public init(localizations: [String: Node]? = nil, defaultLocale: String? = nil) {
        self.localizations = localizations ?? [:]
        self.defaultDialect = defaultLocale ?? localizations?.keys.first ?? "default"
    }

    public subscript(_ languageCode: String, _ paths: PathIndexer...) -> String {
        return self[languageCode, paths]
    }

    public subscript(_ languageCode: String, _ paths: [PathIndexer]) -> String {
        return localizations[languageCode.lowercased()]?[paths]?.string  // Index by language
            ?? localizations[defaultDialect]?[paths]?.string // Index the default language
            ?? paths.map { "\($0)" }.joined(separator: ".") // Return the literal path indexed if no translation
    }
}

extension Localization: CustomDebugStringConvertible {
    public var debugDescription: String {
        var d = ""
        d += "Localization:\n"
        d += "Default Dialect: '\(defaultDialect)'\n"
        d += "Content:\n\(localizations)\n\n"
        return d
    }
}
