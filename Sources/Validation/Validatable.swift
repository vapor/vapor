/// Capable of being validated.
public protocol Validatable: Codable, ValidationDataRepresentable {
    /// The validations that will run when `.validate()`
    /// is called on an instance of this class.
    static var validations: Validations { get }
}

extension Validatable {
    /// See ValidationDataRepresentable.makeValidationData()
    public func makeValidationData() -> ValidationData {
        return .validatable(self)
    }
}

extension Validatable {
    /// Validates the model, throwing an error
    /// if any of the validations fail.
    /// note: non-validation errors may also be thrown
    /// should the validators encounter unexpected errors.
    public func validate() throws {
        var errors: [ValidationError] = []

        for (key, validation) in Self.validations.storage {
            /// fetch the value for the key path and
            /// convert it to validation data
            let data = (self[keyPath: key] as ValidationDataRepresentable).makeValidationData()

            /// run the validation, catching validation errors
            do {
                try validation.validate(data)
            } catch var error as ValidationError {
                error.keyPath += Self.unsafeCodingPath(forKey: key)
                errors.append(error)
            }
        }

        if !errors.isEmpty {
            throw ValidatableError(errors)
        }
    }
}

/// a collection of errors thrown by a validatable
/// models validations
struct ValidatableError: ValidationError {
    /// the errors thrown
    var errors: [ValidationError]

    /// See ValidationError.keyPath
    var keyPath: [CodingKey]

    /// See ValidationError.reason
    var reason: String {
        return errors.map { error in
            var error = error
            error.keyPath = keyPath + error.keyPath
            return error.reason
        }.joined(separator: ", ")
    }

    /// creates a new validatable error
    public init(_ errors: [ValidationError]) {
        self.errors = errors
        self.keyPath = []
    }
}
