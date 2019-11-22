/// Type used by `Range` and `Count` validators to indicate where a value fell within a range.
public enum RangeResult<T>: Equatable where T: Comparable{
    /// The value was between `min` and `max`.
    case between(min: T, max: T)

    /// The value was greater than or equal to `min`.
    case greaterThanOrEqualToMin(T)

    /// The value was greater than `max`.
    case greaterThanMax(T)

    /// The value was less than or equal to `max`.
    case lessThanOrEqualToMax(T)

    /// The value was less than `min`.
    case lessThanMin(T)

    var isWithinRange: Bool {
        switch self {
        case .between, .greaterThanOrEqualToMin, .lessThanOrEqualToMax: return true
        case .greaterThanMax, .lessThanMin: return false
        }
    }

    var description: String {
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

    init(min: T?, max: T?, value: T) {
        precondition(min != nil || max != nil, "Either `min` or `max` has to be non-nil")
        switch (min, max) {
        case let (.some(min), .some(max)) where value >= min && value <= max:
            self = .between(min: min, max: max)
        case let (.some(min), _) where value < min:
            self = .lessThanMin(min)
        case let (_, .some(max)) where value > max:
            self = .greaterThanMax(max)
        case let (.some(min), _):
            self = .greaterThanOrEqualToMin(min)
        case let (_, .some(max)):
            self = .lessThanOrEqualToMax(max)
        case (.none, .none):
            // This cannot happen because all static methods on `Validator` that can make
            // the count and range validators all result in at least a minimum or a maximum or both.
            fatalError("No minimum or maximum was supplied to the Count validator")
        }
    }
}
