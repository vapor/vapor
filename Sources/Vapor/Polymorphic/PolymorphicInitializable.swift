/**
    Initializes an object from a 
    Polymorphic type.
*/
public protocol PolymorphicInitializable {
    init(polymorphic: Polymorphic) throws
}

public enum PolymorphicInitializableError: ErrorProtocol {
    case couldNotInitialize
}

extension String: PolymorphicInitializable {
    public init(polymorphic: Polymorphic) throws {
        guard let string = polymorphic.string else {
            throw PolymorphicInitializableError.couldNotInitialize
        }
        self = string
    }
}

extension Int: PolymorphicInitializable {
    public init(polymorphic: Polymorphic) throws {
        guard let int = polymorphic.int else {
            throw PolymorphicInitializableError.couldNotInitialize
        }
        self = int
    }
}
