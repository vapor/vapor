/// Indicates that a particular type can be validated by count or length
public protocol Countable: Validatable {
    // The type that will be used to evaluate the count
    associatedtype CountType: Comparable, Equatable

    // The count of the object
    var count: CountType { get }
}

/// Use this to validate the count of a given countable type
///
/// "someString".validated(by: Count.min(3) + OnlyAlphanumeric.self)
///
/// - min:         validate count is >= associated value
/// - max:         validate count <= associated value
/// - equals:      validate count == associated value
/// - containedIn: validate low is <= count and count is <= max
public enum Count<Input: Countable>: Validator {
    public typealias CountType = Input.CountType
    case min(CountType)
    case max(CountType)
    case equals(CountType)
    case containedIn(low: CountType, high: CountType)

    /// Validate that a string passes associated length evaluation
    ///
    /// - parameter value: input string to validate
    ///
    ///     - throws: an error if validation fails
    public func validate(_ input: Input) throws {
        let count = input.count
        switch self {
        case .min(let m) where count >= m:
            break
        case .max(let m) where count <= m:
            break
        case .equals(let e) where count == e:
            break
        case .containedIn(low: let l, high: let h) where l <= count && count <= h:
            break
        default:
            let reason = errorReason(with: input)
            throw error(reason)
        }
    }

    private func errorReason(with input: Input) -> String {
        var reason = "\(input) count \(input.count) is "

        switch self {
        case .min(let m):
            reason += "less than minimum \(m)"
        case .max(let m):
            reason += "greater than maximum \(m)"
        case .equals(let e):
            reason += "doesn't equal \(e)"
        case .containedIn(low: let l, high: let h):
            reason += "not contained in \(l...h)"
        }

        return reason
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
