import Core
import HTTP
import Foundation

public final class DateMiddleware: Middleware {
    public func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        let promise = Promise<Response>()

        try next.respond(to: request).then { res in
            res.headers[.date] = Date().description
            try! promise.complete(res)
        }

        return promise.future
    }
}
