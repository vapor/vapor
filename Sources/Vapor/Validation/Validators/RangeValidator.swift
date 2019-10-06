extension Validator where T: Comparable {
    /// Validates that the data is within the supplied `ClosedRange`.
    public static func range(_ range: ClosedRange<T>) -> Validator<T> {
        RangeValidator(min: range.lowerBound, max: range.upperBound).validator()
    }

    /// Validates that the data is less than the supplied upper bound using `PartialRangeThrough`.
    public static func range(_ range: PartialRangeThrough<T>) -> Validator<T> {
        RangeValidator(min: nil, max: range.upperBound).validator()
    }

    /// Validates that the data is less than the supplied lower bound using `PartialRangeFrom`.
    public static func range(_ range: PartialRangeFrom<T>) -> Validator<T> {
        RangeValidator(min: range.lowerBound, max: nil).validator()
    }
}

extension Validator where T: Comparable & Strideable {
    /// Validates that the data is within the supplied `Range`.
    public static func range(_ range: Range<T>) -> Validator<T> {
        RangeValidator(min: range.lowerBound, max: range.upperBound.advanced(by: -1)).validator()
    }
}

public enum RangeValidatorFailure<T: Comparable & Decodable>: ValidatorFailure {
    case lessThan(min: T)
    case greaterThan(max: T)
}

/// Validates whether the data is within a supplied int range.
struct RangeValidator<T: Comparable & Decodable>: ValidatorType {

    /// the minimum possible value, if nil, not checked
    /// - note: inclusive
    let min: T?

    /// the maximum possible value, if nil, not checked
    /// - note: inclusive
    let max: T?

    /// See `ValidatorType`.
    func validate(_ data: T) -> RangeValidatorFailure<T>? {
        if let min = self.min, data < min {
            return .lessThan(min: min)
        }

        if let max = self.max, data > max {
            return .greaterThan(max: max)
        }

        return nil
    }
}
