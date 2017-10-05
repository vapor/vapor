import Async
import Debugging
import HTTP

/// Adds the current `Date` to each `Response`
public final class ErrorMiddleware: Middleware {
    /// See `Middleware.respond`
    public func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        let promise = Promise(Response.self)

        do {
            try next.respond(to: req).then { res in
                promise.complete(res)
            }.catch { error in
                debugPrint(error)
                promise.complete(error.makeResponse())
            }
        } catch {
            debugPrint(error)
            promise.complete(error.makeResponse())
        }

        return promise.future
    }
}

extension Swift.Error {
    /// Creates a response for a given error
    fileprivate func makeResponse() -> Response {
        let reason: String
        if let debuggable = self as? Debuggable {
            reason = debuggable.reason
        } else {
            reason = "Unknown reason."
        }

        let res = try! Response(
            status: .internalServerError,
            body: "Oops: \(reason)"
        )
        return res
    }
}
