import Foundation

/// Components of a router path.
///
/// [Learn More →](https://docs.vapor.codes/3.0/routing/parameters/)
public enum PathComponent: ExpressibleByStringLiteral {
    /// Create a path component from a string
    public init(stringLiteral value: String) {
        let data = value.split(separator: "/").map(String.init).map { Data($0.utf8) }
        self = .constants(data)
    }
    
    /// A normal, constant path component.
    case constants([Data])

    /// A dynamic parameter component.
    case parameter(Data)
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
        return PathComponent(stringLiteral: self)
    }
}
