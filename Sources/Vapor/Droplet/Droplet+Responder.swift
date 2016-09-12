import HTTP
import HTTPRouting

extension Droplet: Responder {
    /**
        Returns a response to the given request

        - parameter request: received request
        - throws: error if something fails in finding response
        - returns: response if possible
    */
    public func respond(to request: Request) throws -> Response {
        log.info("\(request.method) \(request.uri.path)")

        var responder: Responder
        let request = request

        /*
            The HEAD method is identical to GET.

            https://tools.ietf.org/html/rfc2616#section-9.4
        */
        let originalMethod = request.method
        if case .head = request.method {
            request.method = .get
        }

        // Loop through middlewares in order, then pass result to router responder
        responder = enabledMiddleware.chain(to: routerResponder)

        var response: Response
        do {
            response = try responder.respond(to: request)

            if response.headers["Content-Type"] == nil {
                log.warning("Response had no 'Content-Type' header.")
            }
        } catch {
            let message: String

            if environment == .production {
                message = "Something went wrong"
            } else {
                message = "Uncaught Error: \(type(of: error)).\(error). Use middleware to catch this error and provide a better response. Otherwise, a generic error page will be returned in the production environment."
            }

            response = Response(
                status: .internalServerError,
                headers: [
                    "Content-Type": "plaintext"
                ],
                body: message.bytes
            )
        }

        response.headers["Server"] = "Vapor \(Vapor.VERSION)"

        /**
            The server MUST NOT return a message-body in the response for HEAD.

            https://tools.ietf.org/html/rfc2616#section-9.4
         */
        if case .head = originalMethod {
            // TODO: What if body is set to chunked¿?
            response.body = .data([])
        }
        
        return response
    }
}
