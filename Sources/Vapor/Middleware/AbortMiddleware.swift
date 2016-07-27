import Engine

/**
    Handles the various Abort errors that can be thrown
    in any Vapor closure.

    To stop this behavior, remove the
    AbortMiddleware for the Droplet's `middleware` array.
*/
public class AbortMiddleware: Middleware {

    /**
     Respond to a given request chaining to the next

     - parameter request: request to process
     - parameter chain: next responder to pass request to

     - throws: an error on failure

     - returns: a valid response
     */
    public func respond(to request: HTTPRequest, chainingTo chain: HTTPResponder) throws -> HTTPResponse {
        do {
            return try chain.respond(to: request)
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

    func errorResponse(_ status: Status, message: String) throws -> HTTPResponse {
        let json = try JSON([
            "error": true,
            "message": "\(message)"
        ])
        let data = try json.makeBytes()
        let response = HTTPResponse(status: status, body: .data(data))
        response.headers["Content-Type"] = "application/json; charset=utf-8"
        return response
    }

}
