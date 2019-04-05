extension Validator where T: Comparable {
    /// Validates that the data is within the supplied `ClosedRange`.
    ///
    ///     try validations.add(\.age, .range(5...10))
    ///
    public static func range(_ range: ClosedRange<T>) -> Validator<T> {
        return RangeValidator(min: range.lowerBound, max: range.upperBound).validator()
    }

    /// Validates that the data is less than the supplied upper bound using `PartialRangeThrough`.
    ///
    ///     try validations.add(\.age, .range(...10))
    ///
    public static func range(_ range: PartialRangeThrough<T>) -> Validator<T> {
        return RangeValidator(min: nil, max: range.upperBound).validator()
    }

    /// Validates that the data is less than the supplied lower bound using `PartialRangeFrom`.
    ///
    ///     try validations.add(\.age, .range(5...))
    ///
    public static func range(_ range: PartialRangeFrom<T>) -> Validator<T> {
        return RangeValidator(min: range.lowerBound, max: nil).validator()
    }
}

extension Validator where T: Comparable & Strideable {
    /// Validates that the data is within the supplied `Range`.
    ///
    ///     try validations.add(\.age, .range(5..<10))
    ///
    public static func range(_ range: Range<T>) -> Validator<T> {
        return RangeValidator(min: range.lowerBound, max: range.upperBound.advanced(by: -1)).validator()
    }
}

// MARK: Private

/// Validates whether the data is within a supplied int range.
private struct RangeValidator<T>: ValidatorType where T: Comparable, T: Codable {
    /// See `ValidatorType`.
    var validatorReadable: String {
        if let min = self.min, let max = self.max {
            return "between \(min) and \(max)"
        } else if let min = self.min {
            return "at least \(min)"
        } else if let max = self.max {
            return "at most \(max)"
        } else {
            return "valid"
        }
    }

    /// the minimum possible value, if nil, not checked
    /// - note: inclusive
    let min: T?

    /// the maximum possible value, if nil, not checked
    /// - note: inclusive
    let max: T?

    /// creates an is count validator using a partial range from
    ///     5...
    init(min: T?, max: T?) {
        self.min = min
        self.max = max
    }

    /// See `ValidatorType`.
    func validate(_ data: T) -> ValidatorFailure? {
        if let min = self.min {
            guard data >= min else {
                return .init("is less than \(min)")
            }
        }

        if let max = self.max {
            guard data <= max else {
                return .init("is greater than \(max)")
            }
        }
        
        return nil
    }
}
