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
    static func validations(_ validations: inout Validations)
}

extension Validatable {
    public static func validate(content request: Request) throws {
        try self.validations().validate(request: request).assert()
    }
    
    public static func validate(query request: Request) throws {
        try self.validations().validate(query: request.url).assert()
    }
    
    public static func validate(json: String) throws {
        try self.validations().validate(json: json).assert()
    }
    
    public static func validate(query: URI) throws {
        try self.validations().validate(query: query).assert()
    }
    
    public static func validate(_ decoder: Decoder) throws {
        try self.validations().validate(decoder).assert()
    }
    
    public static func validations() -> Validations {
        var validations = Validations()
        self.validations(&validations)
        return validations
    }
}
