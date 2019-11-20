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
    public static func validate(from decoder: Decoder) throws {
        try validations().validate(from: decoder)
    }
    
    public static func validate(json: String) throws {
        try validations().validate(json: json)
    }
}
