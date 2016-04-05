/**
    Handles the various Abort errors that can be thrown
    in any Vapor closure.

    To stop this behavior, remove the
    AbortMiddleware for the Application's `middleware` array.
*/
public class AbortMiddleware: Middleware {

    public func respond(request: Request, chain: Responder) throws -> Response {
        do {
            return try chain.respond(request)
        } catch Abort.badRequest {
            return try self.errorResponse(.badRequest, message: "Invalid request")
        } catch Abort.notFound {
            return try self.errorResponse(.notFound, message: "Page not found")
        } catch Abort.internalServerError {
            return try self.errorResponse(.internalServerError, message: "Something went wrong")
        } catch Abort.invalidParameter(let name, let type) {
            return try self.errorResponse(
                .badRequest,
                message: "Invalid request. Expected parameter \(name) to be type \(type)"
            )
        } catch Abort.custom(let status, let message) {
            return try self.errorResponse(status, message: message)
        }
    }

    func errorResponse(status: Response.Status, message: String) throws -> Response {
        let json = Json([
            "error": "true",
            "message": "\(message)"
        ])
        return Response(status: status, json: json)
    }

}
