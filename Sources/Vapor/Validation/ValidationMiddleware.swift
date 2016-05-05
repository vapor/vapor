/**
    Catches validation errors and prints
    out a more readable JSON response.
 */
class ValidationMiddleware: Middleware {

    func respond(to request: Request, chainingTo chain: Responder) throws -> Response {
        do {
            return try chain.respond(to: request)
        } catch is ValidationFailure {
            let json = Json([
                "error": true,
                "message": "Validation failed."
            ])
            return Response(status: .badRequest, json: json)
        }
    }
    
}
