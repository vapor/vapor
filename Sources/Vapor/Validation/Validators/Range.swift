extension Validator where T: Comparable {

    /// Validates that the data is within the supplied `ClosedRange`.
    public static func range(_ range: ClosedRange<T>) -> Validator<T> {
        Range(min: range.lowerBound, max: range.upperBound).validator()
    }

    /// Validates that the data is less than the supplied upper bound using `PartialRangeThrough`.
    public static func range(_ range: PartialRangeThrough<T>) -> Validator<T> {
        Range(min: nil, max: range.upperBound).validator()
    }

    /// Validates that the data is less than the supplied lower bound using `PartialRangeFrom`.
    public static func range(_ range: PartialRangeFrom<T>) -> Validator<T> {
        Range(min: range.lowerBound, max: nil).validator()
    }
}

extension Validator where T: Comparable & Strideable {

    /// Validates that the data is within the supplied `Range`.
    public static func range(_ range: Swift.Range<T>) -> Validator<T> {
        Range(min: range.lowerBound, max: range.upperBound.advanced(by: -1)).validator()
    }
}

extension Validator where T: Comparable {

    /// `ValidatorResult` of a validator that validates whether the data is within a supplied range.
    public enum RangeValidatorResult: ValidatorResult {

        /// The data was between `min` and `max`.
        case between(min: T, max: T)

        /// The data was greater than or equal to `min`.
        case greaterThanOrEqualToMin(T)

        /// The data was greater than `max`.
        case greaterThanMax(T)

        /// The data was less than or equal to `max`.
        case lessThanOrEqualToMax(T)

        /// The data was less than `min`.
        case lessThanMin(T)

        /// See `CustomStringConvertible`.
        public var description: String {
            switch self {
            case let .between(min, max):
                return "between \(min) and \(max)"
            case let .greaterThanOrEqualToMin(min):
                return "greater than or equal to minimum of \(min)"
            case let .greaterThanMax(max):
                return "greater than maximum of \(max)"
            case let .lessThanMin(min):
                return "less than minimum of \(min)"
            case let .lessThanOrEqualToMax(max):
                return "less than or equal to maximum of \(max)"
            }
        }

        /// See `ValidatorResult`.
        public var failed: Bool {
            switch self {
            case .between, .greaterThanOrEqualToMin, .lessThanOrEqualToMax: return false
            case .greaterThanMax, .lessThanMin: return true
            }
        }
    }

    struct Range: ValidatorType {
        let min: T?
        let max: T?

        func validate(_ comparable: T) -> RangeValidatorResult {
            switch (min, max) {
            case let (.some(min), .some(max)) where comparable >= min && comparable <= max:
                return .between(min: min, max: max)
            case let (.some(min), _) where comparable < min:
                return .lessThanMin(min)
            case let (_, .some(max)) where comparable > max:
                return .greaterThanMax(max)
            case let (.some(min), _):
                return .greaterThanOrEqualToMin(min)
            case let (_, .some(max)):
                return .lessThanOrEqualToMax(max)
            case (.none, .none):
                // This cannot happen because the four static methods on `Validator` that can make
                // this validator all result in at least a minimum or a maximum or both.
                fatalError("No minimum or maximum was supplied to the Range validator")
            }
        }
    }
}
