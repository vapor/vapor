/**
    Validates a given sequence is unique
*/
public struct Unique<
    T>: _Validator where
    T: Sequence,
    T: _Validatable,
    T.Iterator.Element: Equatable
{

    public init() {}

    /**
        validate
    */
    public func validate(_ sequence: T) throws {
        var uniqueValues: [T.Iterator.Element] = []
        for value in sequence {
            if uniqueValues.contains(value) {
                throw error("\(sequence) is not unique)")
            } else {
                uniqueValues.append(value)
            }
        }
    }
}
