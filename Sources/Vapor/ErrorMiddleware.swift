import Async
import Debugging
import HTTP

public final class ErrorMiddleware: Middleware {
    public func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        let promise = Promise(Response.self)

        try next.respond(to: req).then { res in
            promise.complete(res)
        }.catch { error in
            // print(request)
            debugPrint(error)

            let reason: String
            if let debuggable = error as? Debuggable {
                reason = debuggable.reason
            } else {
                reason = "No idea what happened."
            }

            let res = try! Response(status: .internalServerError, body: "Oops: \(reason)")
            promise.complete(res)
        }

        return promise.future
    }
}
