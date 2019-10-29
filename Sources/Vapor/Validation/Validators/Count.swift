extension Validator where T: Collection {

    /// Validates that the data's count is within the supplied `ClosedRange`.
    public static func count(_ range: ClosedRange<Int>) -> Validator<T> {
        Count(min: range.lowerBound, max: range.upperBound).validator()
    }

    /// Validates that the data's count is less than the supplied upper bound using `PartialRangeThrough`.
    public static func count(_ range: PartialRangeThrough<Int>) -> Validator<T> {
        Count(min: nil, max: range.upperBound).validator()
    }

    /// Validates that the data's count is less than the supplied lower bound using `PartialRangeFrom`.
    public static func count(_ range: PartialRangeFrom<Int>) -> Validator<T> {
        Count(min: range.lowerBound, max: nil).validator()
    }

    /// Validates that the data's count is within the supplied `Range`.
    public static func count(_ range: Swift.Range<Int>) -> Validator<T> {
        Count(min: range.lowerBound, max: range.upperBound.advanced(by: -1)).validator()
    }

    /// Validates whether the item's count is within a supplied int range.
    public struct Count: ValidatorType {
        public enum Result: ValidatorResult {
            case between(min: Int, max: Int)
            case greaterThanOrEqualToMin(Int)
            case greaterThanMax(Int)
            case lessThanOrEqualToMax(Int)
            case lessThanMin(Int)
            case unconstrained

            /// See `CustomStringConvertible`.
            public var description: String {
                func elementDescription(count: Int) -> String {
                    let useSingularForm = count == 1 && count != 0

                    let element = T.Element.self is Character.Type ? "character" : "item"

                    return "\(count) \(element)\(useSingularForm ? "" : "s")"
                }

                switch self {
                case let .between(min, max):
                    return "between \(min) and \(elementDescription(count: max))"
                case let .greaterThanOrEqualToMin(min):
                    return "greater than or equal to minimum of \(elementDescription(count: min))"
                case let .greaterThanMax(max):
                    return "greater than maximum of \(elementDescription(count: max))"
                case let .lessThanMin(min):
                    return "less than minimum of \(elementDescription(count: min))"
                case let .lessThanOrEqualToMax(max):
                    return "less than or equal to maximum of \(elementDescription(count: max))"
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
        let min: Int?

        /// the maximum possible value, if nil, not checked
        /// - note: inclusive
        let max: Int?

        public init(min: Int? = nil, max: Int? = nil) {
            self.min = min
            self.max = max
        }

        /// See `ValidatorType`.
        public func validate(_ data: T) -> Result {
            let count = data.count
            switch (min, max) {
            case let (.some(min), .some(max)) where count >= min && count <= max:
                return .between(min: min, max: max)
            case let (.some(min), _) where count < min:
                return .lessThanMin(min)
            case let (_, .some(max)) where count > max:
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
