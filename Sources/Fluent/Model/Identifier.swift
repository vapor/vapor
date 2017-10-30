import Foundation

/// Types conforming to this protocol may be used
/// as identifiers for Fluent models.
public protocol Identifier: Codable {
    /// The specific type of fluent identifier.
    /// This dictates how the identifier will behave when saved.
    static var identifierType: IdentifierType<Self> { get }
}

/// MARK: Default supported types.

extension Int: Identifier {
    /// See Identifier.identifierType
    public static var identifierType: IdentifierType<Int> {
        return .autoincrementing
    }
}

extension UUID: Identifier {
    /// See Identifier.identifierType
    public static var identifierType: IdentifierType<UUID> {
        return .generated { UUID() }
    }
}

extension String: Identifier {
    /// See Identifier.identifierType
    public static var identifierType: IdentifierType<String> {
        return .supplied
    }
}

