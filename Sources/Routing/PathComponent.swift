/// Components of a router path.
///
/// http://localhost:8000/routing/parameters/
public enum PathComponent {
    /// A normal, constant path component.
    case constant(String)

    /// A dynamic parameter component.
    case parameter(String)
}

/// Capable of being represented by a path component.
///
/// http://localhost:8000/routing/parameters/
public protocol PathComponentRepresentable {
    /// Convert to path component.
    func makePathComponent() -> PathComponent
}

extension PathComponent: PathComponentRepresentable {
    /// See PathComponentRepresentable.makePathComponent()
    public func makePathComponent() -> PathComponent {
        return self
    }
}

// MARK: Array

extension Array where Element == PathComponentRepresentable {
    /// Convert to array of path components.
    public func makePathComponents() -> [PathComponent] {
        return map { $0.makePathComponent() }
    }
}

/// Strings are constant path components.
extension String: PathComponentRepresentable {
    /// Convert string to constant path component.
    /// See PathComponentRepresentable.makePathComponent()
    public func makePathComponent() -> PathComponent {
        return .constant(self) // TODO: .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed))
    }
}
