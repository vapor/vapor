// TODO: Evaluate Countable name, also considered Length. W/ count, 
// sequenceType gets free conformance

/**
 Indicates that a particular type can be validated by count or length
 */
public protocol Countable: Validatable {
    // The type that will be used to evaluate the count
    associatedtype CountType: Comparable

    // The count of the object
    var count: CountType { get }
}

// MARK: Count

/**
 Use this to validate the count of a given countable type
 
     "someString".validated(by: Count.min(3) + Count.min(10))

 - min:         validate length is >= associated value
 - max:         validate length <= associated value
 - containedIn: validate low is <= length and length is <= max
 */
public enum Count<CountableType: Countable>: Validator {
    public typealias CountType = CountableType.CountType
    case min(CountType)
    case max(CountType)
    case containedIn(low: CountType, high: CountType)

    /**
     Validate that a string passes associated length evaluation

     - parameter value: input string to validate

     - throws: an error if validation fails
     */
    public func validate(input value: CountableType) throws {
        let length = value.count
        switch self {
        case .min(let m) where length >= m:
            break
        case .max(let m) where length <= m:
            break
        case .containedIn(low: let l, high: let h) where l <= length && length <= h:
            break
        default:
            throw error(with: value)
        }
    }
}

// MARK: Conformance

extension Array: Countable {}
extension Dictionary: Countable {}

extension Set: Countable {}

extension Int: Countable {}
extension Int8: Countable {}
extension Int16: Countable {}
extension Int32: Countable {}
extension Int64: Countable {}

extension UInt: Countable {}
extension UInt8: Countable {}
extension UInt16: Countable {}
extension UInt32: Countable {}
extension UInt64: Countable {}

extension Float: Countable {}
extension Double: Countable {}

extension String: Countable {
    public var count: Int {
        return characters.count
    }
}

extension Integer {
    public var count: Self {
        return self
    }
}

extension FloatingPoint {
    public var count: Self {
        return self
    }
}
