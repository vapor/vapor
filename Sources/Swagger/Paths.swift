import Routing

public final class Paths: Encodable {
    public var paths = [String: PathItem]()
    
    subscript(path: [PathComponent]) -> PathItem? {
        get {
            return paths[path.makePathTemplate()]
        }
        set {
            paths[path.makePathTemplate()] = newValue
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var encoder = encoder.container(keyedBy: SwaggerKeys.self)
        
        for (path, item) in paths {
            try encoder.encode(item, forKey: SwaggerKeys(stringLiteral: path))
        }
    }
}

internal struct SwaggerKeys: CodingKey, ExpressibleByStringLiteral {
    internal var stringValue: String
    
    internal init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    internal var intValue: Int?
    
    internal init?(intValue: Int) {
        return nil
    }
    
    internal typealias StringLiteralType = String
    
    internal init(stringLiteral value: String) {
        self.stringValue = value
    }
}

fileprivate extension Array where Element == PathComponent {
    func makePathTemplate() -> String {
        return "/" + self.map { component in
            switch component {
            case .constant(let constant):
                return constant
            case .parameter(let parameter):
                return parameter.uniqueSlug
            }
        }.joined(separator: "/")
    }
}
