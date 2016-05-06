/**
    Validates that matches a given input
*/
public struct Matches<T where T: Validatable, T: Equatable>: Validator {
    /**
        The value expected to be in sequence
    */
    public let expecting: T

    /**
        Create a validator to check that a sequence contains the given value

        - parameter expecting: the value expected to be in sequence
    */
    public init(_ expecting: T) {
        self.expecting = expecting
    }

    /**
        validate
    */
    public func validate(input value: T) throws {
        guard value == expecting else {
            throw error(with: value)
        }
    }
}
