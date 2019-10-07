public struct Validation {
    enum ValidationType {
    case nested([Validation], BasicCodingKey, Bool = true)
    case value((KeyedDecodingContainer<BasicCodingKey>) -> (BasicCodingKey, ValidatorFailure)?)
    }
    let type: ValidationType

    public init<T: Decodable>(key: BasicCodingKey, as: T.Type = T.self, required: Bool = true, validator: Validator<T>) {
        type = .value {
            KeyedValidation(required: required, key: key, validator: validator)
                .validate($0)
                .map { (key, $0) }
        }
    }
    public init<T: Decodable>(key: String, as: T.Type = T.self, required: Bool = true, validator: Validator<T>) {
        self.init(key: BasicCodingKey(key), required: required, validator: validator)
    }
    public init<T: Decodable>(key: CodingKey, as: T.Type = T.self, required: Bool = true, validator: Validator<T>) {
        self.init(key: BasicCodingKey(key), required: required, validator: validator)
    }

    public init(key: BasicCodingKey, required: Bool = true, validations: [Validation]) {
        type = .nested(validations, key, required)
    }
    public init(key: String, required: Bool = true, validations: [Validation]) {
        self.init(key: BasicCodingKey(key), required: required, validations: validations)
    }
    public init(key: CodingKey, required: Bool = true, validations: [Validation]) {
        self.init(key: BasicCodingKey(key), required: required, validations: validations)
    }

    public init(key: BasicCodingKey, required: Bool = true, validations: Validation ...) {
        self.init(key: key, required: required, validations: validations)
    }
    public init(key: String, required: Bool = true, validations: Validation ...) {
        self.init(key: BasicCodingKey(key), required: required, validations: validations)
    }
    public init(key: CodingKey, required: Bool = true, validations: Validation ...) {
        self.init(key: BasicCodingKey(key), required: required, validations: validations)
    }

    public init(key: BasicCodingKey, required: Bool = true, validatable: Validatable.Type) {
        self.init(key: key, required: required, validations: validatable.validations())
    }
    public init(key: String, required: Bool = true, validatable: Validatable.Type) {
        self.init(key: BasicCodingKey(key), required: required, validatable: validatable)
    }
    public init(key: CodingKey, required: Bool = true, validatable: Validatable.Type) {
        self.init(key: BasicCodingKey(key), required: required, validatable: validatable)
    }
}

extension Sequence where Element == Validation {
    public func validate(from decoder: Decoder) throws {
        if let error = ValidationsError(try run(on: decoder.container(keyedBy: BasicCodingKey.self))) {
            throw error
        }
    }

    func run(on container: KeyedDecodingContainer<BasicCodingKey>) -> [FailedValidation] {
        flatMap { validation -> [FailedValidation] in
            switch validation.type {
            case let .nested(validations, key, required):
                do {
                    let nestedContainer = try container.nestedContainer(keyedBy: BasicCodingKey.self, forKey: key)
                    return validations.run(on: nestedContainer).map { $0.prependingKey(key) }
                } catch {
                    guard required else {
                        return []
                    }
                    return [.init(key: key, failure: MissingRequiredValueFailure())]
                }
            case let .value(validate):
                return validate(container).map(FailedValidation.init).map { [$0] } ?? []
            }
        }
    }
}

struct KeyedValidation<T: Decodable> {
    let required: Bool
    let key: BasicCodingKey
    let validator: Validator<T>

    func validate(_ container: KeyedDecodingContainer<BasicCodingKey>) -> ValidatorFailure? {
        do {
            if container.contains(key) {
                let data = try container.decode(T.self, forKey: key)
                return validator.validate(data)//.makeValidator().validate(data)
            } else if required {
                return MissingRequiredValueFailure()
            } else {
                return nil
            }
        } catch {
            return TypeMismatchValidatorFailure()
        }
    }
}
