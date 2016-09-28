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

        let routerResponder: Request.Handler = Request.Handler { [weak self] request in
            // Routed handler
            if let handler = self?.router.route(request, with: request) {
                return try handler.respond(to: request)
            } else {
                // Default not found handler
                let normal: [HTTP.Method] = [.get, .post, .put, .patch, .delete]

                if normal.contains(request.method) {
                    throw Abort.notFound
                } else if case .options = request.method {
                    return Response(status: .ok, headers: [
                        "Allow": "OPTIONS"
                        ])
                } else {
                    return Response(status: .notImplemented)
                }
            }
        }

        // Loop through middlewares in order, then pass result to router responder
        responder = middleware.chain(to: routerResponder)

        var response: Response
        do {
            response = try responder.respond(to: request)

            if response.headers["Content-Type"] == nil {
                log.warning("Response had no 'Content-Type' header.")
            }
        } catch {
            if environment == .production {
                return ErrorView.shared.makeResponse(.internalServerError, "Something went wrong.")
            } else {
                let message = "Uncaught Error: \(type(of: error)).\(error). Use middleware to catch this error and provide a better response. Otherwise, a 500 error page will be returned in the production environment."
                response = Response(
                    status: .internalServerError,
                    headers: [
                        "Content-Type": "plaintext"
                    ],
                    body: message.bytes
                )
            }
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
