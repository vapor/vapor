extension Validator where T: Collection {
    /// Validates that the data's count is within the supplied `ClosedRange`.
    public static func count(_ range: ClosedRange<Int>) -> Validator<T> {
        .count(min: range.lowerBound, max: range.upperBound)
    }

    /// Validates that the data's count is less than the supplied upper bound using `PartialRangeThrough`.
    public static func count(_ range: PartialRangeThrough<Int>) -> Validator<T> {
        .count(min: nil, max: range.upperBound)
    }

    /// Validates that the data's count is less than the supplied lower bound using `PartialRangeFrom`.
    public static func count(_ range: PartialRangeFrom<Int>) -> Validator<T> {
        .count(min: range.lowerBound, max: nil)
    }

    /// Validates that the data's count is within the supplied `Range`.
    public static func count(_ range: Swift.Range<Int>) -> Validator<T> {
        .count(min: range.lowerBound, max: range.upperBound.advanced(by: -1))
    }
    
    public static func count(min: Int?, max: Int?) -> Validator<T> {
        let suffix: String
        if T.self is String.Type {
            suffix = "character"
        } else {
            suffix = "item"
        }
        return .range(min: min, max: max, \.count, suffix)
    }
}
