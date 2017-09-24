import Async
import HTTP
import Foundation

/// Adds the current `Date` to each `Response`
public final class DateMiddleware: Middleware {
    /// See `Middleware.respond`
    public func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        let promise = Promise<Response>()

        try next.respond(to: request).then { res in
            res.headers[.date] = Date().description
            promise.complete(res)
        }.catch { error in
            promise.fail(error)
        }

        return promise.future
    }
}
