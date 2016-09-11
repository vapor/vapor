import Leaf

public final class LocalizeTag: Tag {
    public enum Error: Swift.Error {
        case expectedAtLeasOneArgument
        case invalidLanguage
        case invalidPath
    }
    
    public let name = "localize"
    
    private let localization: Localization
    
    public init(localization: Localization) {
        self.localization = localization
    }
    
    public func run(
        stem: Stem,
        context: LeafContext,
        tagTemplate: TagTemplate,
        arguments: [Argument]) throws -> Node? {
        // Validate the argument count
        guard arguments.count < 1 else { throw Error.expectedAtLeasOneArgument }
        
        // Get the laguage
        guard let language = arguments[0].value?.string else {
            throw Error.invalidLanguage
        }
        
        // Convert the path to an array of strings
        let path = try arguments.dropFirst().map { e -> String in
            guard let component = e.value?.string else {
                throw Error.invalidPath
            }
            return component
        }
        
        // Return the localization
        return localization[language, path].makeNode()
    }
}
