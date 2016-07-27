/**
    Initializes an object from a 
    Polymorphic type.
*/
public protocol PolymorphicInitializable {
    init(polymorphic: Polymorphic) throws
}

public enum PolymorphicInitializableError: Swift.Error {
    case couldNotInitialize(String)
}

extension String: PolymorphicInitializable {
    public init(polymorphic: Polymorphic) throws {
        guard let string = polymorphic.string else {
            throw PolymorphicInitializableError.couldNotInitialize("Could not convert \(polymorphic) to String")
        }
        self = string
    }
}

extension Int: PolymorphicInitializable {
    public init(polymorphic: Polymorphic) throws {
        guard let int = polymorphic.int else {
            throw PolymorphicInitializableError.couldNotInitialize("Could not convert \(polymorphic) to Int")
        }
        self = int
    }
}

extension Double: PolymorphicInitializable {
    public init(polymorphic: Polymorphic) throws {
        guard let double = polymorphic.double else {
            throw PolymorphicInitializableError.couldNotInitialize("Could not convert \(polymorphic) to Double")
        }
        self = double
    }
}
