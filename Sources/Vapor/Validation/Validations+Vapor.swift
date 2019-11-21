extension Sequence where Element == Validation {

    /// Validate the data in the body of this `Request` according to the `Validation`s.
    /// - Parameter request: The `Request` containing the data to be validated in the body.
    public func validate(_ request: Request) throws {
        guard let contentType = request.headers.contentType else {
            throw Abort(.unprocessableEntity)
        }
        guard let body = request.body.data else {
            throw Abort(.unprocessableEntity)
        }
        let contentDecoder = try ContentConfiguration.global.requireDecoder(for: contentType)
        let decoder = try contentDecoder.decode(DecoderUnwrapper.self, from: body, headers: request.headers)
        return try validate(from: decoder.decoder)
    }
}

extension Validatable {

    /// Validate the data in the body of this `Request` according to this `Validatable`.
    /// - Parameter request: The `Request` containing the data to be validated in the body.
    public static func validate(_ request: Request) throws {
        try validations().validate(request)
    }
}
