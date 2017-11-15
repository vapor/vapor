import Async
import Debugging
import HTTP

/// Captures all errors and transforms them into an internal server error.
public final class ErrorMiddleware: Middleware {
    /// See `Middleware.respond`
    public func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        let promise = Promise(Response.self)
        
        func handleError(_ error: Swift.Error) {
            // TODO: Don't log on production?
            debugPrint(error)
            
            let reason: String
            if let debuggable = error as? Debuggable {
                reason = debuggable.reason
            } else {
                reason = "Unknown reason."
            }
            
            do {
                let res = try Response(status: .internalServerError, body: "Oops: \(reason)")
                promise.complete(res)
            } catch {
                promise.fail(error)
            }
        }

        do {
            try next.respond(to: req).then { res in
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
