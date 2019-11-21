/// Capable of being validated. Conformance adds a throwing `validate()` method.
///
///     struct User: Validatable {
///         var name: String
///         var age: Int
///
///         static func validations() -> [Validation] {
///             [Validation(key: "name", validator: .count(5...) && .alphanumeric)]
///         }
///     }
public protocol Validatable {
    static func validations() -> [Validation]
}

extension Validatable {

    /// Validate the data in the decoder according to the this `Validatable`.
    /// - Parameter decoder: The decoder containing the values to be validated.
    public static func validate(from decoder: Decoder) throws {
        try validations().validate(from: decoder)
    }

    /// Validate a JSON string according to this `Validatable`.
    /// - Parameter json: The JSON string to be validated.
    public static func validate(json: String) throws {
        try validations().validate(json: json)
    }
}
