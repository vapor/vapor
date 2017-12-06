public struct Validations: ExpressibleByDictionaryLiteral {
    /// Store the key and query field.
    internal var storage: [AnyKeyPath: Validator]

    /// See ExpressibleByDictionaryLiteral
    public init(dictionaryLiteral elements: (ValidationKey, Validator)...) {
        self.storage = [:]
        for (key, validator) in elements {
            storage[key.path] = validator
        }
    }

}

/// A model property containing the
/// Swift key path for accessing it.
public struct ValidationKey {
    /// The Swift keypath
    public var path: AnyKeyPath

    /// The properties type.
    /// Storing this as any since we lost
    /// the type info converting to AnyKeyPAth
    public var type: Any.Type

    /// True if the property on the model is optional.
    /// The `type` is the Wrapped type if this is true.
    public var isOptional: Bool

    /// Create a new model key.
    internal init<T>(path: AnyKeyPath, type: T.Type, isOptional: Bool) {
        self.path = path
        self.type = type
        self.isOptional = isOptional
    }
}


extension Validatable {
    /// Create a validation key for the supplied key path.
    public static func key<T>(_ path: KeyPath<Self, T>) -> ValidationKey where T: ValidationDataRepresentable {
        return ValidationKey(path: path, type: T.self, isOptional: false)
    }

    /// Create a validation key for the supplied key path.
    public static func key<T>(_ path: KeyPath<Self, T?>) -> ValidationKey where T: ValidationDataRepresentable {
        return ValidationKey(path: path, type: T.self, isOptional: true)
    }
}

