/// Components of a router path.
///
/// [Learn More →](https://docs.vapor.codes/3.0/routing/parameters/)
public enum PathComponent {
    /// A normal, constant path component.
    case constant(String)

    /// A dynamic parameter component.
    case parameter(String)
}

/// Capable of being represented by a path component.
///
/// [Learn More →](https://docs.vapor.codes/3.0/routing/parameters/)
public protocol PathComponentsRepresentable {
    /// Convert to path component.
    func makePathComponents() -> [PathComponent]
}

extension PathComponent: PathComponentsRepresentable {
    /// See PathComponentRepresentable.makePathComponent()
    public func makePathComponents() -> [PathComponent] {
        return [self]
    }
}

// MARK: Array

extension Array where Element == PathComponentsRepresentable {
    /// Convert to array of path components.
    public func makePathComponents() -> [PathComponent] {
        return map { $0.makePathComponents() }.reduce([], +)
    }
}

/// Strings are constant path components.
extension String: PathComponentsRepresentable {
    /// Convert string to constant path component.
    /// See PathComponentRepresentable.makePathComponent()
    public func makePathComponents() -> [PathComponent] {
        return self.split(separator: "/").map { component in
            return .constant(String(component))
            // TODO: component.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        }
    }
}
