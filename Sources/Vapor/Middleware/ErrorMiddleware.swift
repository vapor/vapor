import Async
import Debugging
//import HTTP
import Service
import Foundation

/// Captures all errors and transforms them into an internal server error.
public final class ErrorMiddleware: Middleware, Service {
    /// The environment to respect when presenting errors.
    let environment: Environment

    /// Log destination
    let log: Logger

    /// Create a new ErrorMiddleware for the supplied environment.
    public init(environment: Environment, log: Logger) {
        self.environment = environment
        self.log = log
    }

    /// See `Middleware.respond`
    public func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        let promise = req.eventLoop.newPromise(Response.self)

        func handleError(_ error: Swift.Error) {
            let reason: String
            let status: HTTPResponseStatus

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
                log.reportError(error, as: "Error")

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

            let res = req.makeResponse()
            res.http.body = HTTPBody(string: "Oops: \(reason)")
            res.http.status = status
            promise.succeed(result: res)
        }

        do {
            try next.respond(to: req).do { res in
                promise.succeed(result: res)
            }.catch { error in
                handleError(error)
            }
        } catch {
            handleError(error)
        }

        return promise.futureResult
    }
}
