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
        public enum Failure: ValidatorFailure {
            case lessThan(min: Int)
            case greaterThan(max: Int)
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
        public func validate(_ data: T) -> Failure? {
            if let min = self.min, data.count < min {
                return .lessThan(min: min)
            }

            if let max = self.max, data.count > max {
                return .greaterThan(max: max)
            }

            return nil
        }
    }
}

extension Validator.Count.Failure: CustomStringConvertible {

    /// See `CustomStringConvertible`.
    public var description: String {
        switch self {
        case .greaterThan(let max):
            return "is greater than required maximum of \(elementDescription(count: max))"
        case .lessThan(let min):
            return "is less than required minimum of \(elementDescription(count: min))"
        }
    }

    private func elementDescription(count: Int) -> String {
        if T.Element.self is Character.Type {
            return count == 1 ? "1 character" : "\(count) characters"
        } else {
            return count == 1 ? "1 item" : "\(count) items"
        }
    }
}
