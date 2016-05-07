/**
    Validate that a sequence contains a given value
*/
public struct Contains<
    T where
    T: Sequence,
    T: Validatable,
    T.Iterator.Element: Equatable>: Validator {

    /**
        The value expected to be in sequence
    */
    public let expecting: T.Iterator.Element

    /**
        Create a validator to check that a sequence contains the given value

        - parameter expecting: the value expected to be in sequence
     */
    public init(_ expecting: T.Iterator.Element) {
        self.expecting = expecting
    }

    /**
        validate
    */
    public func validate(input sequence: T) throws {
        for element in sequence where element == expecting {
            return
        }

        throw error(with: sequence)
    }
}
