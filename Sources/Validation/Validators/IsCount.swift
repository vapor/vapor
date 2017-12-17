import Foundation

/// Validates whether the data is within a supplied int range.
/// note: strings have length checked, while integers, doubles, and dates have their values checked
public struct IsCount<T>: Validator where T: Comparable {
    /// See Validator.inverseMessage
    public var inverseMessage: String {
        if let min = self.min, let max = self.max {
            return "larger than \(min) or smaller than \(max)"
        } else if let min = self.min {
            return "larger than \(min)"
        } else if let max = self.max {
            return "smaller than \(max)"
        } else {
            return "valid"
        }
    }

    /// the minimum possible value, if nil, not checked
    /// note: inclusive
    public let min: T?

    /// the maximum possible value, if nil, not checked
    /// note: inclusive
    public let max: T?

    /// creates an is count validator using a predefined int range
    ///     1...5
    public init(_ range: ClosedRange<T>) {
        self.min = range.lowerBound
        self.max = range.upperBound
    }

    /// creates an is count validator using a partial range through
    ///     ...5
    public init(_ range: PartialRangeThrough<T>) {
        self.max = range.upperBound
        self.min = nil
    }

    /// creates an is count validator using a partial range from
    ///     5...
    public init(_ range: PartialRangeFrom<T>) {
        self.max = nil
        self.min = range.lowerBound
    }
    
    /// See Validator.validate
    public func validate(_ data: ValidationData) throws {
        switch data {
        case .string(let s):
            if let min = self.min as? Int {
                guard s.count >= min else {
                    throw BasicValidationError("is not at least \(min) characters")
                }
            } else if let min = self.min as? String {
                guard s >= min else {
                    throw BasicValidationError("is not alphabetically equal to or later than \(min) characters")
                }
            }

            if let max = self.max as? Int {
                guard s.count <= max else {
                    throw BasicValidationError("is more than \(max) characters")
                }
            } else if let max = self.max as? String {
                guard s <= max else {
                    throw BasicValidationError("is not alphabetically equal to or before \(max) characters")
                }
            }
        case .int(let int):
            if let min = self.min as? Int {
                guard int >= min else {
                    throw BasicValidationError("is not larger than \(min)")
                }
            } else if let min = self.min as? UInt {
                guard int >= min else {
                    throw BasicValidationError("is not larger than \(min)")
                }
            }
            if let max = self.max as? Int {
                guard int <= max else {
                    throw BasicValidationError("is larger than \(max)")
                }
            } else if let max = self.max as? UInt {
                guard int <= max else {
                    throw BasicValidationError("is larger than \(max)")
                }
            }
        case .uint(let uint):
            if let min = self.min as? Int {
                guard uint >= min else {
                    throw BasicValidationError("is not larger than \(min)")
                }
            } else if let min = self.min as? UInt {
                guard uint >= min else {
                    throw BasicValidationError("is not larger than \(min)")
                }
            }
            if let max = self.max as? Int {
                guard uint <= max else {
                    throw BasicValidationError("is larger than \(max)")
                }
            } else if let max = self.max as? UInt {
                guard uint <= max else {
                    throw BasicValidationError("is larger than \(max)")
                }
            }
        case .double(let double):
            if let min = self.min as? Double {
                guard double >= min else {
                    throw BasicValidationError("is not larger than \(min)")
                }
            }
            if let max = self.max as? Double {
                guard double <= max else {
                    throw BasicValidationError("is larger than \(max)")
                }
            }
        case .date(let date):
            if let earliest = self.min as? Date {
                guard date >= earliest else {
                    throw BasicValidationError("is not equal to or later than \(earliest)")
                }
            }
            if let latest = self.max as? Date {
                guard date <= latest else {
                    throw BasicValidationError("is not equal to or earlier than \(latest)")
                }
            }
            break
        default:
            throw BasicValidationError("is invalid")
        }
    }
}

/// - TODO: The conditional conformance here would not be necessary if the
/// validator instead tracked whether the range it was created with was closed
/// or open, and chose whether to use `<` and `>` or `<=` and `>=` on that
/// basis. That would be the most correct and flexible solution. However, the
/// vast majority of ranges are `Strideable` so this lazy solution is used to
/// avoid making the validator's code _considerably_ more complicated, for now.
extension IsCount where T: Strideable {
    /// creates an is count validator using a predefined int range
    ///     1..<5
    public init(_ range: Range<T>) {
        self.min = range.lowerBound
        self.max = range.upperBound.advanced(by: -1)
    }
}
