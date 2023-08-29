import NIOCore

extension Validator where T: Comparable & Strideable {
    /// Validates that the data is within the supplied `Range`.
    public static func range(_ range: Swift.Range<T>) -> Validator<T> {
        .range(min: range.lowerBound, max: range.upperBound.advanced(by: -1))
    }
}

extension Validator where T: Comparable {
    /// Validates that the data is within the supplied `ClosedRange`.
    public static func range(_ range: ClosedRange<T>) -> Validator<T> {
        .range(min: range.lowerBound, max: range.upperBound)
    }
    
    /// Validates that the data is less than or equal to the supplied upper bound using `PartialRangeThrough`.
    public static func range(_ range: PartialRangeThrough<T>) -> Validator<T> {
        .range(min: nil, max: range.upperBound)
    }
    
    /// Validates that the data is greater than or equal the supplied lower bound using `PartialRangeFrom`.
    public static func range(_ range: PartialRangeFrom<T>) -> Validator<T> {
        .range(min: range.lowerBound, max: nil)
    }
    
    static func range(min: T?, max: T?) -> Validator<T> {
        .range(min: min, max: max, \.self)
    }
}

extension Validator where T: Comparable & SignedInteger {
    /// Validates that the data is less than the supplied upper bound using `PartialRangeUpTo`
    public static func range(_ range: PartialRangeUpTo<T>) -> Validator<T> {
        .range(min: nil, max: range.upperBound.advanced(by: -1))
    }
}

extension Validator {
    static func range<U>(
        min: U?, max: U?, _ keyPath: KeyPath<T, U>,
        _ suffix: String? = nil
    ) -> Validator<T>
    where U: Comparable & Sendable
    {
        let sendableKeyPath = UnsafeMutableTransferBox(keyPath)
        return .init { data in
            if let result = try? RangeResult.init(min: min, max: max, value: data[keyPath: sendableKeyPath.wrappedValue]) {
                return ValidatorResults.Range(
                    result: result,
                    suffix: suffix
                )
            }
            // if the above try? returned nil a RangeResultError.notComparable was thrown
            return ValidatorResults.Invalid(reason: "Value in Range is not comparable")
        }
    }
}

// TODO: Remove when keypaths are `Sendable`
/// ``UnsafeMutableTransferBox`` can be used to make non-`Sendable` values `Sendable` and mutable.
/// It can be used to capture local mutable values in a `@Sendable` closure and mutate them from within the closure.
/// As the name implies, the usage of this is unsafe because it disables the sendable checking of the compiler and does not add any synchronisation.
@usableFromInline
final class UnsafeMutableTransferBox<Wrapped> {
    @usableFromInline
    var wrappedValue: Wrapped
    
    @inlinable
    init(_ wrappedValue: Wrapped) {
        self.wrappedValue = wrappedValue
    }
}

extension UnsafeMutableTransferBox: @unchecked Sendable {}

extension ValidatorResults {
    /// `ValidatorResult` of a validator that validates whether the input is within a supplied range.
    public struct Range<T> where T: Comparable & Sendable {
        /// The position of the data relative to the range.
        public let result: RangeResult<T>
        
        internal let suffix: String?
    }
}

extension ValidatorResults.Range: ValidatorResult {
    public var isFailure: Bool {
        !self.result.isWithinRange
    }
    
    public var successDescription: String? {
        self.description
    }
    
    public var failureDescription: String? {
        self.description
    }
    
    private var description: String {
        if let suffix = self.suffix {
            return "is \(self.result.description) \(suffix)(s)"
        } else {
            return "is \(self.result.description)"
        }
    }
}
