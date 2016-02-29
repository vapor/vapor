public class AbortMiddleware: Middleware {

    public func handle(handler: Request.Handler) -> Request.Handler {
        return { request in
            do {
                return try handler(request: request)
            } catch Abort.BadRequest {
                return try self.errorResponse(.BadRequest, message: "Invalid request")
            } catch Abort.NotFound {
                return try self.errorResponse(.NotFound, message: "Page not found")
            } catch Abort.InternalServerError {
                return try self.errorResponse(.Error, message: "Something went wrong")
            } catch Abort.Custom(let status, let message) {
                return try self.errorResponse(status, message: message)
            }
        }
    }
    
    private func errorResponse(status: Response.Status, message: String) throws -> Response {
        let json = try Json([
            "error": "true",
            "message": message
        ])
        let data = try json.serialize()
        return Response(status: status, data: data, contentType: .Json)
    }
    
}
