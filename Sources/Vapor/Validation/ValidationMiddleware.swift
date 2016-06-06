/**
    Catches validation errors and prints
    out a more readable JSON response.
*/
class ValidationMiddleware: Middleware {

    func respond(to request: Request, closure: (Request) throws -> Response) throws -> Response {
        do {
            return try closure(request)
        } catch let error as ValidationErrorProtocol {
            let json = JSON([
                "error": true,
                "message": error.message
            ])
            return Response(status: .badRequest, json: json)
        }
    }
    
}
