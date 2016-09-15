import HTTP

/**
    Handles the various Abort errors that can be thrown
    in any Vapor closure.

    To stop this behavior, remove the
    AbortMiddleware for the Droplet's `middleware` array.
*/
public class AbortMiddleware: Middleware {
    public init() { }

    /**
        Respond to a given request chaining to the next

        - parameter request: request to process
        - parameter chain: next responder to pass request to

        - throws: an error on failure

        - returns: a valid response
     */
    public func respond(to request: Request, chainingTo chain: Responder) throws -> Response {
        do {
            return try chain.respond(to: request)
        } catch Abort.badRequest {
            return try AbortMiddleware.errorResponse(request, .badRequest, "Invalid request")
        } catch Abort.notFound {
            return try AbortMiddleware.errorResponse(request, .notFound, "Page not found")
        } catch Abort.serverError {
            return try AbortMiddleware.errorResponse(request, .internalServerError, "Something went wrong")
        } catch Abort.custom(let status, let message) {
            return try AbortMiddleware.errorResponse(request, status, message)
        }
    }

    static func errorResponse(_ request: Request, _ status: Status, _ message: String) throws -> Response {
        if request.accept.prefers("html") {
            return ErrorView.shared.makeResponse(status, message)
        }

        let json = try JSON(node: [
            "error": true,
            "message": "\(message)"
            ])
        let data = try json.makeBytes()
        let response = Response(status: status, body: .data(data))
        response.headers["Content-Type"] = "application/json; charset=utf-8"
        return response
    }

}

