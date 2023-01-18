public struct Validation {
    let run: (KeyedDecodingContainer<ValidationKey>) -> ValidationResult

    init<T>(key: ValidationKey, required: Bool, validator: Validator<T>, customFailureDescription: String?) {
        self.init { container in
            let result: ValidatorResult
            do {
                if container.contains(key), try !container.decodeNil(forKey: key) {
                    result = try validator.validate(container.decode(T.self, forKey: key))
                } else if required {
                    result = ValidatorResults.Missing()
                } else {
                    result = ValidatorResults.Skipped()
                }
            } catch DecodingError.valueNotFound {
                result = ValidatorResults.NotFound()
           } catch DecodingError.typeMismatch(let type, _) {
                result = ValidatorResults.TypeMismatch(type: type)
            } catch DecodingError.dataCorrupted(let context) {
                result = ValidatorResults.Invalid(reason: context.debugDescription)
            } catch {
               result = ValidatorResults.Codable(error: error)
           }
            
            return .init(key: key, result: result, customFailureDescription: customFailureDescription)
        }
    }
    
    init(nested key: ValidationKey, required: Bool, keyed validations: Validations, customFailureDescription: String?) {
        self.init { container in
            let result: ValidatorResult
            do {
                if container.contains(key), !required, try container.decodeNil(forKey: key) {
                    result = ValidatorResults.Skipped()
                } else if container.contains(key) {
                    let nested = try container.nestedContainer(keyedBy: ValidationKey.self, forKey: key)
                    let results = validations.validate(nested)
                    result = ValidatorResults.Nested(results: results.results)
                } else if required {
                    result = ValidatorResults.Missing()
                } else {
                    result = ValidatorResults.Skipped()
                }
            } catch {
                result = ValidatorResults.Codable(error: error)
            }
            return .init(key: key, result: result, customFailureDescription: customFailureDescription)
        }
    }
    
    init(nested key: ValidationKey, required: Bool, unkeyed factory: @escaping (Int, inout Validations) -> (), customFailureDescription: String?) {
        self.init { container in
            let result: ValidatorResult
            do {
                if container.contains(key), !required, try container.decodeNil(forKey: key) {
                    result = ValidatorResults.Skipped()
                } else if container.contains(key) {
                    var results: [[ValidatorResult]] = []
                    var array = try container.nestedUnkeyedContainer(forKey: key)
                    var i = 0
                    while !array.isAtEnd {
                        defer { i += 1 }
                        var validations = Validations()
                        factory(i, &validations)
                        let nested = try array.nestedContainer(keyedBy: ValidationKey.self)
                        let result = validations.validate(nested)
                        results.append(result.results)
                    }
                    result = ValidatorResults.NestedEach(results: results)
                } else if required {
                    result = ValidatorResults.Missing()
                } else {
                    result = ValidatorResults.Skipped()
                }
            } catch {
                result = ValidatorResults.Codable(error: error)
            }
            return .init(key: key, result: result, customFailureDescription: customFailureDescription)
        }
    }
    
    init(key: ValidationKey, result: ValidatorResult, customFailureDescription: String?) {
        self.init { decoder in
            .init(key: key, result: result, customFailureDescription: customFailureDescription)
        }
    }
    
    init(run: @escaping (KeyedDecodingContainer<ValidationKey>) -> ValidationResult) {
        self.run = run
    }
}

public struct ValidationResult {
    public let key: ValidationKey
    public let result: ValidatorResult
    public let customFailureDescription: String?
    
    init(key: ValidationKey, result: ValidatorResult, customFailureDescription: String? = nil) {
        self.key = key
        self.result = result
        self.customFailureDescription = customFailureDescription
    }
}

extension ValidationResult: ValidatorResult {
    public var isFailure: Bool {
        self.result.isFailure
    }
    
    public var successDescription: String? {
        self.result.successDescription
            .map { "\(self.key) \($0)" }
    }
    
    public var failureDescription: String? {
        self.result.failureDescription
            .map { "\(self.key) \($0)" }
    }
}
