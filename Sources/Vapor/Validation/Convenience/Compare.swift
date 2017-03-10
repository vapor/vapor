/// Validate a comparable
///
/// - greaterThan: validate input is > associated value
/// - greaterThanOrEqual: validate input is >= associated value
/// - lessThan: validate input is < associated value
/// - lessThanOrEqual: validate input is <= associated value
/// - equals: validate input == associated value
/// - containedIn: validate low <= input && input <= high
public enum Compare<Input>: Validator where Input: Comparable, Input: Validatable {
    case greaterThan(Input)
    case greaterThanOrEqual(Input)
    case lessThan(Input)
    case lessThanOrEqual(Input)
    case equals(Input)
    case containedIn(low: Input, high: Input)

    /// Validate that a string passes associated compare evaluation
    ///
    /// - parameter value: input string to validate
    ///
    /// - throws: an error if validation fails
    public func validate(_ input: Input) throws {
        switch self {
        case .greaterThan(let c) where input > c:
            break
        case .greaterThanOrEqual(let c) where input >= c:
            break
        case .lessThan(let c) where input < c:
            break
        case .lessThanOrEqual(let c) where input <= c:
            break
        case .equals(let e) where input == e:
            break
        case .containedIn(low: let l, high: let h) where l <= input && input <= h:
            break
        default:
            let reason = errorReason(with: input)
            throw error(reason)
        }
    }

    private func errorReason(with input: Input) -> String {
        var reason = "\(input) is not "

        switch self {
        case .greaterThan(let c):
            reason += "greater than \(c)"
        case .greaterThanOrEqual(let c):
            reason += "greater than or equal to \(c)"
        case .lessThan(let c):
            reason += "less than \(c)"
        case .lessThanOrEqual(let c):
            reason += "less than or equal to \(c)"
        case .equals(let e):
            reason += "equal to \(e)"
        case .containedIn(low: let l, high: let h):
            reason += "not contained in \(l...h)"
        }

        return reason
    }
}
