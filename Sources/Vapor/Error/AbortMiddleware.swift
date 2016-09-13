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
            return try errorResponse(request, .badRequest, "Invalid request")
        } catch Abort.notFound {
            return try errorResponse(request, .notFound, "Page not found")
        } catch Abort.serverError {
            return try errorResponse(request, .internalServerError, "Something went wrong")
        } catch Abort.custom(let status, let message) {
            return try errorResponse(request, status, message)
        }
    }

    func errorResponse(_ request: Request, _ status: Status, _ message: String) throws -> Response {
        if request.accept.prefers("html") {
            return ErrorView.shared.makeResponse(status, message)
        } else {
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

}

