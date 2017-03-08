    /// Validates a given sequence is unique
public struct Unique<T>: Validator
    where
    T: Sequence,
    T: Validatable,
    T.Iterator.Element: Equatable
{
    public init() {}
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
