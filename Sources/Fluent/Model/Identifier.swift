public enum IdentifierType<I: Identifier> {
    case autoincrementing
    public typealias IdentifierFactory = () -> I
    case generated(IdentifierFactory)
    case supplied
}

public protocol Identifier: Codable {
    static var identifierType: IdentifierType<Self> { get }
}

extension Int: Identifier {
    public static var identifierType: IdentifierType<Int> {
        return .autoincrementing
    }
}

import Foundation

extension UUID: Identifier {
    public static var identifierType: IdentifierType<UUID> {
        return .generated { UUID() }
    }
}

extension String: Identifier {
    public static var identifierType: IdentifierType<String> {
        return .supplied
    }
}
