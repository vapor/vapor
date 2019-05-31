/// Capable of being validated. Conformance adds a throwing `validate()` method.
///
///     struct User: Validatable, Reflectable {
///         var name: String
///         var age: Int
///
///         static func validations() throws -> Validations<User> {
///             var validations = Validations(User.self)
///             // validate name is at least 5 characters and alphanumeric
///             try validations.add(\.name, .count(5...) && .alphanumeric)
///             return validations
///         }
///     }
///
public protocol Validatable {
    /// The validations that will run when `validate()` is called on an instance of this class.
    ///
    ///     struct User: Validatable, Reflectable {
    ///         var name: String
    ///         var age: Int
    ///
    ///         static func validations() throws -> Validations<User> {
    ///             var validations = Validations(User.self)
    ///             // validate name is at least 5 characters and alphanumeric
    ///             try validations.add(\.name, .count(5...) && .alphanumeric)
    ///             return validations
    ///         }
    ///     }
    ///
    static func validations() -> Validations
}

extension Validatable {
    public static func validate(_ request: Request) throws {
        guard let contentType = request.headers.contentType else {
            throw Abort(.unprocessableEntity)
        }
        guard let body = request.body.data else {
            throw Abort(.unprocessableEntity)
        }
        let contentDecoder = try ContentConfiguration.global.requireDecoder(for: contentType)
        let decoder = try contentDecoder.decode(DecoderUnwrapper.self, from: body, headers: request.headers)
        try self.validate(from: decoder.decoder)
    }
    public static func validate(json: String) throws {
        let decoder = try JSONDecoder().decode(DecoderUnwrapper.self, from: Data(json.utf8))
        try Self.validate(from: decoder.decoder)
    }

    public static func validate(from decoder: Decoder) throws {
        try Self.validations().run(on: decoder)
    }
}
