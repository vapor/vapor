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

    /// Validates whether the data is within a supplied int range.
    public struct Range: ValidatorType {
        public enum Result: ValidatorResult {
            case between(min: T, max: T)
            case greaterThanOrEqualToMin(T)
            case greaterThanMax(T)
            case lessThanOrEqualToMax(T)
            case lessThanMin(T)
            case unconstrained

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
                case .unconstrained:
                    return "unconstrained"
                }
            }

            /// See `ValidatorResult`.
            public var failed: Bool {
                switch self {
                case .between, .greaterThanOrEqualToMin, .lessThanOrEqualToMax, .unconstrained: return false
                case .greaterThanMax, .lessThanMin: return true
                }
            }
        }

        /// the minimum possible value, if nil, not checked
        /// - note: inclusive
        let min: T?

        /// the maximum possible value, if nil, not checked
        /// - note: inclusive
        let max: T?

        public init(min: T? = nil, max: T? = nil) {
            self.min = min
            self.max = max
        }

        /// See `ValidatorType`.
        public func validate(_ comparable: T) -> Result {
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
                return .unconstrained
            }
        }
    }
}
