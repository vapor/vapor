/**
    Any type that conforms to this protocol
    can be passed as a requirement to Vapor's
    type-safe route calls.
*/
public protocol StringInitializable {
    init?(from string: String) throws
}

///Allow the Int type to be a type-safe routing parameter
extension Int: StringInitializable {
    public init?(from string: String) throws {
        guard let int = Int(string) else {
            return nil
        }

        self = int
    }
}

///Allow the String type to be a type-safe routing parameter
extension String: StringInitializable {
    public init?(from string: String) throws {
        self = string
    }
}
