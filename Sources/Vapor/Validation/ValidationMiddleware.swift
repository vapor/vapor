import HTTP

/**
    Catches validation errors and prints
    out a more readable JSON response.
*/
public class ValidationMiddleware: Middleware {

    public init() {}

    public func respond(to request: Request, chainingTo chain: Responder) throws -> Response {
        do {
            return try chain.respond(to: request)
        } catch let error as ValidationErrorProtocol {
            let json = try JSON(node: [
                "error": true,
                "message": error.message
            ])
            let data = try json.makeBytes()
            return Response(status: .badRequest, body: .data(data))
        }
    }
    
}
