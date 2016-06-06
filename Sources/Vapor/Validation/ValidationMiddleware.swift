/**
    Catches validation errors and prints
    out a more readable JSON response.
*/
class ValidationMiddleware: Middleware {

    func handle(_ handler: Request.Handler) -> Request.Handler {
        return { request in
            do {
                return try handler(request)
            } catch let error as ValidationErrorProtocol {
                let json = JSON([
                    "error": true,
                    "message": error.message
                ])
                return Response(status: .badRequest, json: json)
            }
        }
    }
    
}
