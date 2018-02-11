/// Combines two validators into an or validator
public func && (lhs: Validator, rhs: Validator) -> Validator {
    return AndValidator(lhs, rhs)
}

/// Combines two validators, if either both succeed
/// the validation will succeed.
internal struct AndValidator: Validator {
    /// See Validator.inverseMessage
    public var inverseMessage: String {
        return "\(lhs.inverseMessage) and \(rhs.inverseMessage)"
    }

    /// left validator
    let lhs: Validator

    /// right validator
    let rhs: Validator

    /// create a new and validator
    init(_ lhs: Validator, _ rhs: Validator) {
        self.lhs = lhs
        self.rhs = rhs
    }

    /// See Validator.validate
    func validate(_ data: ValidationData) throws {
        var left: ValidationError?
        do {
            try lhs.validate(data)
        } catch let l as ValidationError {
            left = l
        }

        var right: ValidationError?
        do {
            try rhs.validate(data)
        } catch let r as ValidationError {
            right = r
        }

        if left != nil || right != nil {
            throw AndValidatorError(left, right)
        }
    }
}

/// Error thrown if and validation fails
internal struct AndValidatorError: ValidationError {
    /// error thrown by left validator
    let left: ValidationError?

    /// error thrown by right validator
    let right: ValidationError?

    /// See ValidationError.reason
    var reason: String {
        if let left = left, let right = right {
            var mutableLeft = left, mutableRight = right
            mutableLeft.codingPath = codingPath + left.codingPath
            mutableRight.codingPath = codingPath + right.codingPath
            return "\(mutableLeft.reason) and \(mutableRight.reason)"
        } else if let left = left {
            var mutableLeft = left
            mutableLeft.codingPath = codingPath + left.codingPath
            return mutableLeft.reason
        } else if let right = right {
            var mutableRight = right
            mutableRight.codingPath = codingPath + right.codingPath
            return mutableRight.reason
        } else {
            return ""
        }
    }

    /// See ValidationError.keyPath
    var codingPath: [CodingKey]

    /// Creates a new or validator error
    init(_ left: ValidationError?, _ right: ValidationError?) {
        self.left = left
        self.right = right
        self.codingPath = []
    }
}

