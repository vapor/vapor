/// Holds zero or more validations for a `Validatable` model.
public struct Validations: CustomStringConvertible {
    /// Internal storage.
    fileprivate var storage: [AnyValidation]

    /// See `CustomStringConvertible`.
    public var description: String {
        return storage.map { $0.description }.description
    }

    /// Create an empty `Validations` struct. You can also use an empty array `[]`.
    public init() {
        self.storage = []
    }
    
    public mutating func add<T>(_ path: CodingKeyRepresentable..., as type: T.Type, is validator: Validator<T>) {
        return self.add(path, as: T.self, is: validator)
    }

    /// Adds a new `Validation` at the supplied path.
    ///
    ///     validations.add("name", as: String.self, is: .count(5...) && .alphanumeric)
    ///
    /// Use optionals to indicate whether a `nil` value is supported. Use the `required` label
    /// to indicate whether or not validation should fail if the key is missing.
    ///
    ///     // email key must exist and contain a valid email
    ///     validations.add("email", as: String.self, is: .email)
    ///     // email key may be omitted, but must be valid if present
    ///     validations.add("email", as: String.self, is: .email, required: false)
    ///     // email key must be present, but can be nil, or a valid email
    ///     validations.add("email", as: String?.self, is: .nil || .email)
    ///     // email may be omitted, null, or a valid email
    ///     validations.add("email", as: String?.self, is: .nil || .email, required: false)
    ///
    /// When validating optionals, the `.nil` validator can be combined with `||` and `&&`
    /// to match against non-optional supporting validators.
    ///
    ///     // validation passes if nil or, if not nil, alphanumeric
    ///     add("name", as: String?, is: .nil || .alphanumeric)
    ///
    /// The `!` operator can be used to invert any validator, including the `nil` validator.
    ///
    ///     // validation passes if not nil and not alphanumeric
    ///     add("name", as: String?, is: !.nil && !.alphanumeric)
    ///
    /// - parameters:
    ///     - path: Coding path of value to be validated.
    ///     - type: Type to decode for validation.
    ///     - validator: Validator to use.
    ///     - required: If `true`, validation will fail if no value is found for the given key path.
    ///                 If `false`, validation will be skipped if no value exists for the given key path.
    ///                 Defaults to `true`.
    public mutating func add<T>(_ path: [CodingKeyRepresentable], as type: T.Type, is validator: Validator<T>, required: Bool = true) {
        let validation = Validaton(path: path.map { $0.codingKey }, validator: validator, required: required)
        self.storage.append(validation)
    }

    /// Runs the `Validation`s on a `Decoder`.
    public func run(on decoder: Decoder) throws {
        let failures = self.storage.compactMap { $0.validate(decoder) }
        if !failures.isEmpty {
            throw ValidationError(failures)
        }
    }
}

public protocol AnyValidation: CustomStringConvertible {
    var path: [CodingKey] { get }
    func validate(_ decoder: Decoder) -> ValidationFailure?
}

struct Validaton<T>: AnyValidation where T: Codable {
    let path: [CodingKey]
    let validator: Validator<T>
    let required: Bool
    
    var description: String {
        let description = "\(self.path.dotPath) is \(validator)"
        if self.required {
            return description
        } else {
            return description + " if present"
        }
    }
    
    init(path: [CodingKey], validator: Validator<T>, required: Bool) {
        self.path = path
        self.validator = validator
        self.required = required
    }
    
    func validate(_ decoder: Decoder) -> ValidationFailure? {
        guard self.path.count > 0 else {
            fatalError()
        }
        
        var path = self.path
        let last = path.popLast()!
        
        let failure: ValidatorFailure?
        do {
            var container = try decoder.container(keyedBy: BasicCodingKey.self)
            for part in path {
                container = try container.nestedContainer(keyedBy: BasicCodingKey.self, forKey: .key(part.stringValue))
            }
            if container.contains(.key(last.stringValue)) {
                let data = try container.decode(T.self, forKey: .key(last.stringValue))
                failure = self.validator.validate(data)
            } else if self.required {
                failure = .init("required")
            } else {
                failure = nil
            }
        } catch {
            let typeName: String
            if let optional = T.self as? AnyOptionalType.Type {
                typeName = "\(optional.anyWrappedType)"
            } else {
                typeName = "\(T.self)"
            }
            let article: String
            if let first = typeName.first, "aeiou".contains(first.lowercased()) {
                article = "an"
            } else {
                article = "a"
            }
            failure = .init("is not \(article) \(typeName)")
        }
        return failure.flatMap { ValidationFailure(path: self.path, failure: $0) }
    }
}
