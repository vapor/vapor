/// Validate that is in given collection
public struct In<
    T>: Validator where
    T: Validatable,
    T: Equatable
{

    private let collection: [T]

    /// Create in validation against passed iterator
    ///
    /// - parameter sequence: the sequence to check if contains
    public init<S: Sequence>(_ sequence: S) where S.Iterator.Element == T {
        collection = Array(sequence)
    }

    public func validate(_ input: T) throws {
        for next in collection where next == input {
            return
        }
        throw error("\(collection) does not contain \(input)")
    }
}
