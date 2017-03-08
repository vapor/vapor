import HTTP

/// Catches validation errors and prints
/// out a more readable JSON response.
public class ValidationMiddleware: Middleware {

    public init() {}

    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        do {
            return try next.respond(to: request)
        } catch let error as ValidationError {
            var json = JSON([:])
            try json.set("error", true)
            try json.set("message", error.reason)

            let response = Response(status: .badRequest)
            response.json = json
            return response
        }
    }
    
}
