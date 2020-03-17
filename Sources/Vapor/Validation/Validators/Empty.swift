extension Validator where T: Collection {
    /// Validates that the data is empty. You can also check a non empty state by negating this validator: `!.empty`.
    public static var empty: Validator<T> {
        .init {
            ValidatorResults.Empty(isEmpty: $0.isEmpty)
        }
    }
}

extension ValidatorResults {
    /// `ValidatorResult` of a validator that validates whether the data is empty.
    public struct Empty {
        /// The input is empty.
        public let isEmpty: Bool
    }
}

extension ValidatorResults.Empty: ValidatorResult {
    public var isFailure: Bool {
        !self.isEmpty
    }
    
    public var successDescription: String? {
        "is empty"
    }
    
    public var failureDescription: String? {
        "is not empty"
    }
}
