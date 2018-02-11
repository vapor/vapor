/// Inverts a validator into a not validator
public prefix func ! (rhs: Validator) -> Validator {
    return NotValidator(rhs)
}

/// Inverts a validator
internal struct NotValidator: Validator {
    /// See Validator.inverseMessage
    public var inverseMessage: String {
        return "not \(rhs.inverseMessage)"
    }

    /// right validator
    let rhs: Validator

    /// create a new not validator
    init(_ rhs: Validator) {
        self.rhs = rhs
    }

    /// See Validator.validate
    func validate(_ data: ValidationData) throws {
        var error: ValidationError?
        do {
            try rhs.validate(data)
        } catch let e as ValidationError {
            error = e
        }
        guard error != nil else {
            throw BasicValidationError("is \(rhs.inverseMessage)")
        }
    }
}
