/**
    Catches validation errors and prints
    out a more readable JSON response.
*/
class ValidationMiddleware: Middleware {

    func respond(to request: Request, chainingTo chain: Responder) throws -> Response {
        do {
            return try chain.respond(to: request)
        } catch let error as ValidationErrorProtocol {
            let json = JSON([
                "error": true,
                "message": error.message
            ])
            return Response(status: .badRequest, json: json)
        }
    }
    
}
