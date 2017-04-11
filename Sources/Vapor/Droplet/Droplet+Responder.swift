import HTTP
import Routing

extension Droplet: Responder {
    /// Returns a response to the given request
    ///
    /// - parameter request: received request
    /// - throws: error if something fails in finding response
    /// - returns: response if possible
    public func respond(to request: Request) -> Response {
        log.info("\(request.method) \(request.uri.path)")
        
        let isHead = request.method == .head
        if isHead {
            /// The HEAD method is identical to GET.
            ///
            /// https://tools.ietf.org/html/rfc2616#section-9.4
            request.method = .get
        }
        
        let response: Response
        do {
            response = try responder.respond(to: request)
        } catch {
            logError(error)
            response = errorRenderer.make(with: request, for: error)
        }
        
        if isHead {
            /// The server MUST NOT return a message-body in the response for HEAD.
            ///
            /// https://tools.ietf.org/html/rfc2616#section-9.4
            response.body = .data([])
        }
        
        return response
    }
    
    private func logError(_ error: Error) {
        if let debuggable = error as? Debuggable {
            log.error(debuggable.loggable)
        } else {
            let type = String(reflecting: type(of: error))
            log.error("[\(type): \(error)]")
            log.info("Conform '\(type)' to Debugging.Debuggable to provide more debug information.")
        }
    }
}
