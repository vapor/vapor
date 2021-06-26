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
        let validation = Validation(nested: key, required: required, keyed: validations)
        self.storage.append(validation)
    }
    
    public mutating func add(
        each key: ValidationKey,
        required: Bool = true,
        _ handler: @escaping (Int, inout Validations) -> ()
    ) {
        let validation = Validation(nested: key, required: required, unkeyed: handler)
        self.storage.append(validation)
    }
    
    public func validate(request: Request) throws -> ValidationsResult {
        guard let contentType = request.headers.contentType else {
            throw Abort(.unprocessableEntity, reason: "Missing \"Content-Type\" header")
        }
        guard let body = request.body.data else {
            throw Abort(.unprocessableEntity, reason: "Empty Body")
        }
        let contentDecoder = try ContentConfiguration.global.requireDecoder(for: contentType)
        let decoder = try contentDecoder.decode(DecoderUnwrapper.self, from: body, headers: request.headers)
        return try self.validate(decoder.decoder)
    }
    
    public func validate(query: URI) throws -> ValidationsResult {
        let urlDecoder = try ContentConfiguration.global.requireURLDecoder()
        let decoder = try urlDecoder.decode(DecoderUnwrapper.self, from: query)
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

