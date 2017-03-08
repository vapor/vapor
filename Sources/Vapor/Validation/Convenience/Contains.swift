
/// Validate that a sequence contains a given value
public struct Contains<T>: Validator where T: Sequence, T: Validatable, T.Iterator.Element: Equatable {
    /// The value expected to be in sequence
    public let expecting: T.Iterator.Element

    /// Create a validator to check that a sequence contains the given value
    ///
    /// - parameter expecting: the value expected to be in sequence
    public init(_ expecting: T.Iterator.Element) {
        self.expecting = expecting
    }

    /// validate
    public func validate(_ input: T) throws {
        if input.contains(expecting) { return }
        throw error("\(input) does not contain \(expecting)")
    }
}
