import Async
import Debugging
import HTTP
import Service

/// Captures all errors and transforms them into an internal server error.
public final class ErrorMiddleware: Middleware {
    /// The environment to respect when presenting errors.
    let environment: Environment

    /// Create a new ErrorMiddleware for the supplied environment.
    public init(environment: Environment) {
        self.environment = environment
    }

    /// See `Middleware.respond`
    public func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        let promise = Promise(Response.self)

        func handleError(_ error: Swift.Error) {
            // TODO: Don't log on production?

            let reason: String
            let status: HTTPStatus

            switch environment {
            case .production:
                if let abort = error as? AbortError {
                    reason = abort.reason
                    status = abort.status
                } else {
                    status = .internalServerError
                    reason = "Something went wrong."
                }
            default:
                if let debuggable = error as? Debuggable {
                    reason = debuggable.reason
                } else if let abort = error as? AbortError {
                    reason = abort.reason
                } else {
                    reason = "Something went wrong."
                }

                if let abort = error as? AbortError {
                    status = abort.status
                } else {
                    status = .internalServerError
                }
            }

            if let debuggable = error as? Debuggable {
                print(debuggable.debuggableHelp(format: .long))
            } else {
                debugPrint(error)
            }

            let res = req.makeResponse()
            res.http.body = HTTPBody(string: "Oops: \(reason)")
            res.http.status = status
            promise.complete(res)
        }

        do {
            try next.respond(to: req).do { res in
                promise.complete(res)
            }.catch { error in
                handleError(error)
            }
        } catch {
            handleError(error)
        }

        return promise.future
    }
}
