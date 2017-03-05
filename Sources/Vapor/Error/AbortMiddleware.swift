import HTTP

/**
    Handles the various Abort errors that can be thrown
    in any Vapor closure.

    To stop this behavior, remove the
    AbortMiddleware for the Droplet's `middleware` array.
*/
public class AbortMiddleware: Middleware {
    let environment: Environment
    public init(environment: Environment = .production) {
        self.environment = environment
    }

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
        } catch let error as AbortError {
            return try errorResponse(request, error)
        } catch {
            let errorType = type(of: error)
            let message = "\(errorType): \(error)"
            return try errorResponse(request, .internalServerError, message)
        }
    }

    // MARK: Private
    
    private func errorResponse(_ request: Request, _ status: Status, _ message: String) throws -> Response {
        let error = Abort.custom(status: status, message: message)
        return try errorResponse(request, error)
    }
    
    private func errorResponse(_ request: Request, _ error: AbortError) throws -> Response {
        if environment == .production {
			log.error("Uncaught Error: \(type(of: error)).\(error)")
			
            let message = error.code < 500 ? error.message : "Something went wrong"

            if request.accept.prefers("html") {
                return ErrorView.shared.makeResponse(error.status, message)
            }

            let response = Response(status: error.status)
            response.json = try JSON(node: [
                "error": true,
                "message": message,
                "code": error.code
            ])
            return response
        } else {
            if request.accept.prefers("html") {
                return ErrorView.shared.makeResponse(error.status, error.message)
            }

            let response = Response(status: error.status)
            response.json = try JSON(node: [
                "error": true,
                "message": error.message,
                "code": error.code,
                "metadata": error.metadata
            ])
            return response
        }
    }

    // MARK: Deprecated

    @available(*, deprecated: 1.5, message: "This method will be removed in a future version.")
    public static func errorResponse(_ request: Request, _ status: Status, _ message: String) throws -> Response {
        return try AbortMiddleware().errorResponse(request, status, message)
    }

    @available(*, deprecated: 1.5, message: "This method will be removed in a future version.")
    public static func errorResponse(_ request: Request, _ error: AbortError) throws -> Response {
        return try AbortMiddleware().errorResponse(request, error)
    }
}

