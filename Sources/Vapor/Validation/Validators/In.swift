extension Validator where T: Equatable {
    /// Validates whether an item is contained in the supplied array.
    public static func `in`(_ array: T...) -> Validator<T> {
        .in(array)
    }

    /// Validates whether an item is contained in the supplied sequence.
    public static func `in`<S>(_ sequence: S) -> Validator<T>
        where S: Sequence, S.Element == T
    {
        .init {
            ValidatorResults.In(item: $0, items: .init(sequence))
        }
    }
}

extension ValidatorResults {
    /// `ValidatorResult` of a validator that validates whether an item is contained in the supplied sequence.
    public struct In<T> where T: Equatable {
        /// Description of the item.
        public let item: T
        
        /// Descriptions of the elements of the supplied sequence.
        public let items: [T]
    }

}

extension ValidatorResults.In: ValidatorResult {
    public var isFailure: Bool {
        !self.items.contains(self.item)
    }
    
    public var successDescription: String? {
        "in \(self.items)"
    }
    
    public var failureDescription: String? {
        "not in \(self.items)"
    }
}
