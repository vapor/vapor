/// Represents how a value for a key should be validated.
public struct Validation {
    enum ValidationType {
    case nested([Validation], BasicCodingKey, Bool = true)
    case preValidated(PathedValidatorResult)
    case value((KeyedDecodingContainer<BasicCodingKey>) -> (BasicCodingKey, ValidatorResult)?)
    }

    let type: ValidationType

    /// Creates a new `Validation` based on a `Validator`.
    ///
    /// - Parameters:
    ///   - key: The key to the value to be validated.
    ///   - as: The type of the value to be validated.
    ///   - required: Fail on absense of the value.
    ///   - validator: The validator to use for validation.
    public init<T: Decodable>(_ key: String, as: T.Type = T.self, required: Bool = true, is validator: Validator<T>) {
        let key = BasicCodingKey(key)
        type = .value {
            KeyedValidation(required: required, key: key, validator: validator)
                .validate($0)
                .map { (key, $0) }
        }
    }

    /// Creates a new `Validation` for a nested object.
    ///
    /// - Parameters:
    ///   - key: The key to the nested  value to be validated.
    ///   - required: Fail on absense of the value.
    ///   - validations: The validations the apply to the nested object.
    public init(_ key: String, required: Bool = true, validations: [Validation]) {
        type = .nested(validations, BasicCodingKey(key), required)
    }

    /// Creates a new `Validation` for a nested object.
    ///
    /// - Parameters:
    ///   - key: The key to the nested  value to be validated.
    ///   - required: Fail on absense of the value.
    ///   - validations: The validations the apply to the nested object.
    public init(_ key: String, required: Bool = true, validations: Validation ...) {
        self.init(key, required: required, validations: validations)
    }

    /// Creates a new `Validation` for a nested object.
    ///
    /// - Parameters:
    ///   - key: The key to the nested  value to be validated.
    ///   - required: Fail on absense of the value.
    ///   - validatable: The type representing how to validate the nested object.
    public init(_ key: String, required: Bool = true, validatable: Validatable.Type) {
        self.init(key, required: required, validations: validatable.validations())
    }

    /// Creates a new `Validation` from an existing `ValidatorResult` and a key.
    ///
    /// This allows you to include `ValidatorResults` that are impossible to achieve using the `validate(from:)` method,
    /// eg. when the validation requires a database lookup.
    ///
    /// - Parameter key: The key associated with the result.
    /// - Parameter result: The pre-existing `ValidatorResult`.
    public init(_ key: String, result: ValidatorResult) {
        type = .preValidated(.init(key: BasicCodingKey.key(key), result: result))
    }
}

extension Validation {

    /// `ValidatorResult` for missing values where they were expected (ie. `required` == `true`).
    public struct MissingRequiredValue: ValidatorResult {
        public let failed = true
        public let description = "Missing required value"
    }

    /// `ValidatorResult` for values that were not of the expected type.
    public struct TypeMismatch: ValidatorResult {
        public let failed = true
        public let description = "Unexpected type encountered"
    }
}

extension Sequence where Element == Validation {

    /// Validate a JSON string according to the `Validation`s.
    /// - Parameter json: The JSON string to be validated.
    public func validate(json: String) throws {
        let decoder = try JSONDecoder().decode(DecoderUnwrapper.self, from: Data(json.utf8))
        try self.validate(from: decoder.decoder)
    }

    /// Validate the data in the decoder according to the the `Validation`s.
    /// - Parameter decoder: The decoder containing the values to be validated.
    public func validate(from decoder: Decoder) throws {
        if let error = ValidationsError(try run(on: decoder.container(keyedBy: BasicCodingKey.self))) {
            throw error
        }
    }

    func run(on container: KeyedDecodingContainer<BasicCodingKey>) -> [PathedValidatorResult] {
        flatMap { validation -> [PathedValidatorResult] in
            switch validation.type {
            case let .nested(validations, key, required):
                do {
                    let nestedContainer = try container.nestedContainer(keyedBy: BasicCodingKey.self, forKey: key)
                    return validations.run(on: nestedContainer).map { $0.prependingKey(key) }
                } catch {
                    guard required else {
                        return []
                    }
                    return [.init(key: key, result: Validation.MissingRequiredValue())]
                }
            case let .preValidated(result):
                return [result]
            case let .value(validate):
                return validate(container).map(PathedValidatorResult.init).map { [$0] } ?? []
            }
        }
    }
}

struct KeyedValidation<T: Decodable> {
    let required: Bool
    let key: BasicCodingKey
    let validator: Validator<T>

    func validate(_ container: KeyedDecodingContainer<BasicCodingKey>) -> ValidatorResult? {
        do {
            if container.contains(key) {
                let data = try container.decode(T.self, forKey: key)
                return validator.validate(data)
            } else if required {
                return Validation.MissingRequiredValue()
            } else {
                return nil
            }
        } catch {
            return Validation.TypeMismatch()
        }
    }
}
