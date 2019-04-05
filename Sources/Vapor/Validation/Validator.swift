public protocol AnyValidation: CustomStringConvertible {
    var path: [CodingKey] { get }
    func validate(_ decoder: Decoder) -> ValidationFailure?
}

#warning("TODO: add IfPresent validation")

/// A discrete `Validator`. Usually created by calling `ValidatorType.validator()`.
///
/// All validation operators (`&&`, `||`, `!`, etc) work on `Validator`s.
///
///     try validations.add(\.firstName, .count(5...) && .alphanumeric)
///
/// Adding static properties to this type will enable leading-dot syntax when composing validators.
///
///     extension Validator {
///         static var myValidation: Validator<T> { return MyValidator().validator() }
///     }
///
struct Validaton<T>: AnyValidation where T: Codable {
    public var path: [CodingKey]

    /// Validates the supplied `ValidationData`, throwing an error if it is not valid.
    ///
    /// - parameters:
    ///     - data: `ValidationData` to validate.
    /// - throws: `ValidationError` if the data is not valid, or another error if something fails.
    private let validator: Validator<T>

    /// See `CustomStringConvertible`.
    public var description: String {
        return "\(self.path.dotPath) is \(validator)"
    }

    /// Creates a new `Validation`.
    ///
    /// - parameters:
    ///     - readable: Readable name, suitable for placing after `is` _and_ `is not`.
    ///     - validate: Validates the supplied `ValidationData`, throwing an error if it is not valid.
    public init(path: [CodingKey], validator: Validator<T>) {
        self.path = path
        self.validator = validator
    }
    
    public func validate(_ decoder: Decoder) -> ValidationFailure? {
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
            } else {
                failure = .init("required")
            }
        } catch {
            failure = .init("is not a \(T.self)")
        }
        return failure.flatMap { ValidationFailure(path: self.path, failure: $0) }
    }
}
