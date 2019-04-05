/// Holds zero or more validations for a `Validatable` model.
public struct Validations: CustomStringConvertible {
    /// Internal storage.
    fileprivate var storage: [AnyValidation]

    /// See `CustomStringConvertible`.
    public var description: String {
        return storage.map { $0.description }.joined(separator: "\n")
    }

    /// Create an empty `Validations` struct. You can also use an empty array `[]`.
    public init() {
        self.storage = []
    }
    
    public mutating func add<T>(_ path: CodingKeyRepresentable..., as type: T.Type, is validator: Validator<T>) {
        return self.add(path, as: T.self, is: validator)
    }

    /// Adds a new `Validation` at the supplied key path and readable path.
    ///
    ///     try validations.add(\.name, at: ["name"], .count(5...) && .alphanumeric)
    ///
    /// - parameters:
    ///     - keyPath: `KeyPath` to validatable property.
    ///     - path: Readable path. Will be displayed when showing errors.
    ///     - validation: `Validation` to run on this property.
    public mutating func add<T>(_ path: [CodingKeyRepresentable], as type: T.Type, is validator: Validator<T>) {
        let validation = Validaton(path: path.map { $0.codingKey }, validator: validator)
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
