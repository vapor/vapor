/**
    Validates that matches a given input
*/
public struct Matches<T>: _Validator where T: _Validatable, T: Equatable {
    /**
        The value expected to be in sequence
    */
    public let expectation: T

    /**
        Create a validator to check that a sequence contains the given value

        - parameter expecting: the value expected to be in sequence
    */
    public init(_ expectation: T) {
        self.expectation = expectation
    }

    /**
        validate
    */
    public func validate(_ input: T) throws {
        guard input == expectation else {
            throw error("\(input) does not equal expectation \(expectation)")
        }
    }
}
