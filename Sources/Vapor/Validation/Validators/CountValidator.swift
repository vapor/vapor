extension Validator where T: Collection {
    /// Validates that the data's count is within the supplied `ClosedRange`.
    public static func count(_ range: ClosedRange<Int>) -> Validator<T> {
        return CountValidator(min: range.lowerBound, max: range.upperBound).validator()
    }

    /// Validates that the data's count is less than the supplied upper bound using `PartialRangeThrough`.
    public static func count(_ range: PartialRangeThrough<Int>) -> Validator<T> {
        return CountValidator(min: nil, max: range.upperBound).validator()
    }

    /// Validates that the data's count is less than the supplied lower bound using `PartialRangeFrom`.
    public static func count(_ range: PartialRangeFrom<Int>) -> Validator<T> {
        return CountValidator(min: range.lowerBound, max: nil).validator()
    }

    /// Validates that the data's count is within the supplied `Range`.
    public static func count(_ range: Range<Int>) -> Validator<T> {
        return CountValidator(min: range.lowerBound, max: range.upperBound.advanced(by: -1)).validator()
    }
}

public enum CountValidatorFailure: ValidatorFailure {
    case lessThan(min: Int)
    case greaterThan(max: Int)
}

/// Validates whether the item's count is within a supplied int range.
struct CountValidator<T: Collection & Decodable>: ValidatorType {

    /// the minimum possible value, if nil, not checked
    /// - note: inclusive
    let min: Int?

    /// the maximum possible value, if nil, not checked
    /// - note: inclusive
    let max: Int?

    /// See `ValidatorType`.
    func validate(_ data: T) -> CountValidatorFailure? {
        if let min = self.min, data.count < min {
            return .lessThan(min: min)
        }

        if let max = self.max, data.count > max {
            return .greaterThan(max: max)
        }

        return nil
    }
}
