/// Captures all errors and transforms them into an internal server error HTTP response.
public final class ErrorMiddleware: Middleware {
    /// Structure of `ErrorMiddleware` default response.
    internal struct ErrorResponse: Codable {
        /// Always `true` to indicate this is a non-typical JSON response.
        var error: Bool

        /// The reason for the error.
        var reason: String
    }

    /// Create a default `ErrorMiddleware`. Logs errors to a `Logger` based on `Environment`
    /// and converts `Error` to `Response` based on conformance to `AbortError` and `Debuggable`.
    ///
    /// - parameters:
    ///     - environment: The environment to respect when presenting errors.
    ///     - log: Log destination.
    public static func `default`(environment: Environment) -> ErrorMiddleware {
        return .init { req, error in
            // log the error
            #warning("TODO: upgrade to sswg logger")
            print(error)
            // log.report(error: error, verbose: !environment.isRelease)

            // variables to determine
            let status: HTTPResponseStatus
            let reason: String
            let headers: HTTPHeaders

            // inspect the error type
            switch error {
            case let abort as AbortError:
                // this is an abort error, we should use its status, reason, and headers
                reason = abort.reason
                status = abort.status
                headers = abort.headers
                #warning("TODO: add support for validation errors")
//            case let validation as ValidationError:
//                // this is a validation error
//                reason = validation.reason
//                status = .badRequest
//                headers = [:]
//            case let debuggable as Debuggable where !environment.isRelease:
//                // if not release mode, and error is debuggable, provide debug
//                // info directly to the developer
//                reason = debuggable.reason
//                status = .internalServerError
//                headers = [:]
            default:
                // not an abort error, and not debuggable or in dev mode
                // just deliver a generic 500 to avoid exposing any sensitive error info
                reason = "Something went wrong."
                status = .internalServerError
                headers = [:]
            }

            // create a Response with appropriate status
            var res = HTTPResponse(status: status, headers: headers)

            // attempt to serialize the error to json
            do {
                let errorResponse = ErrorResponse(error: true, reason: reason)
                res.body = try HTTPBody(data: JSONEncoder().encode(errorResponse))
                res.headers.replaceOrAdd(name: .contentType, value: "application/json; charset=utf-8")
            } catch {
                res.body = HTTPBody(string: "Oops: \(error)")
                res.headers.replaceOrAdd(name: .contentType, value: "text/plain; charset=utf-8")
            }
            return res
        }
    }

    /// Error-handling closure.
    private let closure: (HTTPRequest, Error) -> (HTTPResponse)

    /// Create a new `ErrorMiddleware`.
    ///
    /// - parameters:
    ///     - closure: Error-handling closure. Converts `Error` to `Response`.
    public init(_ closure: @escaping (HTTPRequest, Error) -> (HTTPResponse)) {
        self.closure = closure
    }

    /// See `Middleware`.
    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<HTTPResponse> {
        return next.respond(to: request).flatMapErrorThrowing { error in
            return self.closure(request.http, error)
        }
    }
}
