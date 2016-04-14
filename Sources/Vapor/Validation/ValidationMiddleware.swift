/**
    Catches validation errors and prints
    out a more readable JSON response.
 */
class ValidationMiddleware: Middleware {

    func respond(request: Request, chain: Responder) throws -> Response {
        do {
            return try chain.respond(request)
        } catch is ValidationFailure<OnlyAlphanumeric> {
            let json = Json([
                "error": true,
                "message": "Validation failed."
            ])
            return Response(status: .badRequest, json: json)
        }
    }
    
}
