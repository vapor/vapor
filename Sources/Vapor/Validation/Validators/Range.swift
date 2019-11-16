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

    /// `ValidatorResult` of a validator that validates whether the input is within a supplied range.
    public struct RangeValidatorResult: ValidatorResult {

        /// The `failed` state is inverted.
        public let isInverted: Bool

        /// The position of the data relative to the range.
        public let rangeResult: RangeResult<T>

        /// See `CustomStringConvertible`.
        public var description: String { rangeResult.describe() }

        /// See `ValidatorResult`.
        public var failed: Bool { !rangeResult.isWithinRange }
    }

    struct Range: ValidatorType {
        let isInverted: Bool
        let min: T?
        let max: T?

        init(isInverted: Bool = false, min: T?, max: T?) {
            self.isInverted = isInverted
            self.min = min
            self.max = max
        }

        func inverted() -> Range {
            .init(isInverted: !isInverted, min: min, max: max)
        }

        func validate(_ comparable: T) -> RangeValidatorResult {
            .init(isInverted: isInverted, rangeResult: .init(min: min, max: max, value: comparable))
        }
    }
}
