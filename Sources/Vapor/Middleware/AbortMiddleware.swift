/**
    Handles the various Abort errors that can be thrown
    in any Vapor closure. 

    To stop this behavior, remove the
    AbortMiddleware for the Application's `middleware` array.
*/
public class AbortMiddleware: Middleware {

    public class func handle(handler: Request.Handler, for application: Application) -> Request.Handler {
        return { request in
            do {
                return try handler(request: request)
            } catch Abort.BadRequest {
                return try self.errorResponse(.BadRequest, message: "Invalid request")
            } catch Abort.NotFound {
                return try self.errorResponse(.NotFound, message: "Page not found")
            } catch Abort.InternalServerError {
                return try self.errorResponse(.Error, message: "Something went wrong")
            } catch Abort.InvalidParameter(let name, let type) {
                return try self.errorResponse(.BadRequest, message: "Invalid request. Expected parameter \(name) to be type \(type)")
            } catch Abort.Custom(let status, let message) {
                return try self.errorResponse(status, message: message)
            }
        }
    }
    
    class func errorResponse(status: Response.Status, message: String) throws -> Response {
        let json = Json([
            "error": "true",
            "message": "\(message)"
        ])
        return Response(status: status, json: json)
    }
    
}
