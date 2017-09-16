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
}

fileprivate extension Array where Element == PathComponent {
    func makePathTemplate() -> String {
        return self.map { component in
            switch component {
            case .constant(let constant):
                return constant
            case .parameter(let parameter):
                return parameter.uniqueSlug
            }
        }.joined(separator: "/")
    }
}
