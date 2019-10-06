import Combine

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
    @available(OSX 10.15, *)
    public static func validate<T: TopLevelDecoder>(_ input: T.Input, using topLevelDecoder: T) throws {
        try validations().validate(input, using: topLevelDecoder)
    }

    public static func validate(from decoder: Decoder) throws {
        try validations().validate(from: decoder)
    }
}
