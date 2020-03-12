public struct Validations {
    var storage: [Validation]
    
    public init() {
        self.storage = []
    }
    
    public mutating func add<T>(
        _ key: ValidationKey,
        as type: T.Type = T.self,
        is validator: Validator<T> = .valid,
        required: Bool = true
    ) {
        let validation = Validation(key: key, required: required, validator: validator)
        self.storage.append(validation)
    }
    
    public mutating func add(
        _ key: ValidationKey,
        result: ValidatorResult
    ) {
        let validation = Validation(key: key, result: result)
        self.storage.append(validation)
    }
    
    public mutating func add(
        _ key: ValidationKey,
        required: Bool = true,
        _ nested: (inout Validations) -> ()
    ) {
        var validations = Validations()
        nested(&validations)
        let validation = Validation(key: key, required: required, nested: validations)
        self.storage.append(validation)
    }
    
    public mutating func addForEach(
        _ key: ValidationKey,
        required: Bool = true,
        _ nested: (inout Validations) -> ()
    ) {
        var validations = Validations()
        nested(&validations)
        let validation = Validation(key: key, required: required, forEachNested: validations)
        self.storage.append(validation)
    }
    
    public func validate(_ request: Request) throws -> ValidationsResult {
        guard let contentType = request.headers.contentType else {
            throw Abort(.unprocessableEntity)
        }
        guard let body = request.body.data else {
            throw Abort(.unprocessableEntity)
        }
        let contentDecoder = try ContentConfiguration.global.requireDecoder(for: contentType)
        let decoder = try contentDecoder.decode(DecoderUnwrapper.self, from: body, headers: request.headers)
        return try self.validate(decoder.decoder)
    }
    
    public func validate(json: String) throws -> ValidationsResult {
        let decoder = try JSONDecoder().decode(DecoderUnwrapper.self, from: Data(json.utf8))
        return try self.validate(decoder.decoder)
    }
    
    public func validate(_ decoder: Decoder) throws -> ValidationsResult {
        try self.validate(decoder.container(keyedBy: ValidationKey.self))
    }

    internal func validate(_ decoder: KeyedDecodingContainer<ValidationKey>) -> ValidationsResult {
        .init(results: self.storage.map {
            $0.run(decoder)
        })
    }
}

