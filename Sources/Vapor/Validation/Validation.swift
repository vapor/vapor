public struct Validation {
    enum ValidationType {
    case nested([Validation], BasicCodingKey, Bool = true)
    case value((KeyedDecodingContainer<BasicCodingKey>) -> (BasicCodingKey, ValidatorResult)?)
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

    public init(key: String, required: Bool = true, validations: [Validation]) {
        type = .nested(validations, BasicCodingKey(key), required)
    }

    public init(key: String, required: Bool = true, validations: Validation ...) {
        self.init(key: key, required: required, validations: validations)
    }

    public init(key: String, required: Bool = true, validatable: Validatable.Type) {
        self.init(key: key, required: required, validations: validatable.validations())
    }
}

extension Validation {
    public struct MissingRequiredValue: ValidatorResult {
        public let failed = true
        public let description = "Missing required value"
    }

    public struct TypeMismatch: ValidatorResult {
        public let failed = true
        public let description = "Unexpected type encountered"
    }
}

extension Sequence where Element == Validation {
    public func validate(json: String) throws {
        let decoder = try JSONDecoder().decode(DecoderUnwrapper.self, from: Data(json.utf8))
        try self.validate(from: decoder.decoder)
    }

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
