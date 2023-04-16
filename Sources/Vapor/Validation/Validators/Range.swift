extension Validator where T: Comparable & Strideable {
    /// Validates that the data is within the supplied `Range`.
    public static func range(_ range: Swift.Range<T>) -> Validator<T> {
        .range(min: range.lowerBound, max: range.upperBound.advanced(by: -1))
    }
}

extension Validator where T: Comparable {
    /// Validates that the data is within the supplied `ClosedRange`.
    public static func range(_ range: ClosedRange<T>) -> Validator<T> {
        .range(min: range.lowerBound, max: range.upperBound)
    }

    /// Validates that the data is less than or equal to the supplied upper bound using `PartialRangeThrough`.
    public static func range(_ range: PartialRangeThrough<T>) -> Validator<T> {
        .range(min: nil, max: range.upperBound)
    }

    /// Validates that the data is greater than or equal the supplied lower bound using `PartialRangeFrom`.
    public static func range(_ range: PartialRangeFrom<T>) -> Validator<T> {
        .range(min: range.lowerBound, max: nil)
    }
    
    static func range(min: T?, max: T?) -> Validator<T> {
        .range(min: min, max: max, \.self)
    }
}

extension Validator where T: Comparable & SignedInteger {
    /// Validates that the data is less than the supplied upper bound using `PartialRangeUpTo`
    public static func range(_ range: PartialRangeUpTo<T>) -> Validator<T> {
        .range(min: nil, max: range.upperBound.advanced(by: -1))
    }
}

extension Validator {
    static func range<U>(
        min: U?, max: U?, _ keyPath: KeyPath<T, U>,
        _ suffix: String? = nil
    ) -> Validator<T>
        where U: Comparable
    {   
        .init { data in 
            if let result = try? RangeResult.init(min: min, max: max, value: data[keyPath: keyPath]) {
                return ValidatorResults.Range(
                    result: result,
                    suffix: suffix
                )
            }
            // if the above try? returned nil a RangeResultError.notComparable was thrown
            return ValidatorResults.Invalid(reason: "Value in Range is not comparable")
        }
    }
}

extension ValidatorResults {
    /// `ValidatorResult` of a validator that validates whether the input is within a supplied range.
    public struct Range<T>: Sendable where T: Comparable & Sendable {
        /// The position of the data relative to the range.
        public let result: RangeResult<T>
        
        internal let suffix: String?
    }
}

extension ValidatorResults.Range: ValidatorResult {
    public var isFailure: Bool {
        !self.result.isWithinRange
    }
    
    public var successDescription: String? {
        self.description
    }
    
    public var failureDescription: String? {
        self.description
    }
    
    private var description: String {
        if let suffix = self.suffix {
            return "is \(self.result.description) \(suffix)(s)"
        } else {
            return "is \(self.result.description)"
        }
    }
}
