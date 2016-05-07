/**
    Validate a comparable


    - greaterThan: validate input is > associated value
    - greaterThanOrEqual: validate input is >= associated value
    - lessThan: validate input is < associated value
    - lessThanOrEqual: validate input is <= associated value
    - equals: validate input == associated value
    - containedIn: validate low <= input && input <= high
*/
public enum Compare<ComparableType where ComparableType: Comparable, ComparableType: Validatable>: Validator {
    public typealias InputType = ComparableType
    case greaterThan(ComparableType)
    case greaterThanOrEqual(ComparableType)
    case lessThan(ComparableType)
    case lessThanOrEqual(ComparableType)
    case equals(ComparableType)
    case containedIn(low: ComparableType, high: ComparableType)

    /**
     Validate that a string passes associated compare evaluation

     - parameter value: input string to validate

     - throws: an error if validation fails
     */
    public func validate(input value: InputType) throws {
        switch self {
        case .greaterThan(let c) where value > c:
            break
        case .greaterThanOrEqual(let c) where value >= c:
            break
        case .lessThan(let c) where value < c:
            break
        case .lessThanOrEqual(let c) where value <= c:
            break
        case .equals(let e) where value == e:
            break
        case .containedIn(low: let l, high: let h) where l <= value && value <= h:
            break
        default:
            throw error(with: value)
        }
    }
}
