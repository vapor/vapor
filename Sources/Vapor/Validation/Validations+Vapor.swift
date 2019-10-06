//import Validations

extension Sequence where Element == Validation {
    func validate(_ request: Request) throws {
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
    static func validate(_ request: Request) throws {
        try validations().validate(request)
    }
}
