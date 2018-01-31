/// Combines two validators into an or validator
public func || (lhs: Validator, rhs: Validator) -> Validator {
    return OrValidator(lhs, rhs)
}

/// Combines two validators, if either is true
/// the validation will succeed.
internal struct OrValidator: Validator {
    /// See Validator.inverseMessage
    public var inverseMessage: String {
        return "\(lhs.inverseMessage) or \(rhs.inverseMessage)"
    }

    /// left validator
    let lhs: Validator

    /// right validator
    let rhs: Validator

    /// create a new or validator
    init(_ lhs: Validator, _ rhs: Validator) {
        self.lhs = lhs
        self.rhs = rhs
    }

    /// See Validator.validate
    func validate(_ data: ValidationData) throws {
        do {
            try lhs.validate(data)
        } catch let left as ValidationError {
            do {
                try rhs.validate(data)
            } catch let right as ValidationError {
                throw OrValidatorError(left, right)
            }
        }
    }
}

/// Error thrown if or validation fails
internal struct OrValidatorError: ValidationError {
    /// error thrown by left validator
    let left: ValidationError

    /// error thrown by right validator
    let right: ValidationError

    /// See ValidationError.reason
    var reason: String {
        var left = self.left
        left.codingPath = codingPath + self.left.codingPath
        var right = self.right
        right.codingPath = codingPath + self.right.codingPath
        return "\(left.reason) and \(right.reason)"
    }

    /// See ValidationError.keyPath
    var codingPath: [CodingKey]

    /// Creates a new or validator error
    init(_ left: ValidationError, _ right: ValidationError) {
        self.left = left
        self.right = right
        self.codingPath = []
    }
}
