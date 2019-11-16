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

    /// `ValidatorResult` of a validator  that validates whether the item's `count` is within a supplied int range.
    public struct CountValidatorResult: ValidatorResult {

        /// The `failed` state is inverted.
        public let isInverted: Bool

        /// The position of the count relative to the range.
        public let rangeResult: RangeResult<Int>

        /// See `CustomStringConvertible`.
        public var description: String {
            rangeResult.describe { count in
                let useSingularForm = count == 1 && count != 0

                let element = T.Element.self is Character.Type ? "character" : "item"

                return "\(count) \(element)\(useSingularForm ? "" : "s")"
            }
        }

        /// See `ValidatorResult`.
        public var failed: Bool {
            rangeResult.isWithinRange == isInverted 
        }
    }

    struct Count: ValidatorType {
        let isInverted: Bool
        let min: Int?
        let max: Int?

        init(isInverted: Bool = false, min: Int?, max: Int?) {
            self.isInverted = isInverted
            self.min = min
            self.max = max
        }

        func inverted() -> Count {
            .init(isInverted: !isInverted, min: min, max: max)
        }

        func validate(_ data: T) -> CountValidatorResult {
            .init(isInverted: isInverted, rangeResult: .init(min: min, max: max, value: data.count))
        }
    }
}
