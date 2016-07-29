import HTTP

/**
    Catches validation errors and prints
    out a more readable JSON response.
*/
class ValidationMiddleware: Middleware {

    func respond(to request: Request, chainingTo chain: HTTPResponder) throws -> HTTPResponse {
        do {
            return try chain.respond(to: request)
        } catch let error as ValidationErrorProtocol {
            let json = try JSON([
                "error": true,
                "message": error.message
            ])
            let data = try json.makeBytes()
            return HTTPResponse(status: .badRequest, body: .data(data))
        }
    }
    
}
