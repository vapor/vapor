/// Components of a router path.
///
/// [Learn More →](https://docs.vapor.codes/3.0/routing/parameters/)
public enum PathComponent: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .constants(value.split(separator: "/").map(String.init))
    }
    
    /// A normal, constant path component.
    case constants([String])

    /// A dynamic parameter component.
    case parameter(String)
}

/// Capable of being represented by a path component.
///
/// [Learn More →](https://docs.vapor.codes/3.0/routing/parameters/)
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
        return .constants(self.split(separator: "/").map(String.init))
    }
}
