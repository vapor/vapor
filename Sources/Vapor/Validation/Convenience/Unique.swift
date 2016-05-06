/**
    Validates a given sequence is unique
*/
public struct Unique<
    T where
    T: Sequence,
    T: Validatable,
    T.Iterator.Element: Equatable>: ValidationSuite {

    /**
        validate
    */
    public static func validate(input sequence: T) throws {
        var uniqueValues: [T.Iterator.Element] = []
        for value in sequence {
            if uniqueValues.contains(value) {
                throw error(with: sequence)
            } else {
                uniqueValues.append(value)
            }
        }
    }
}
