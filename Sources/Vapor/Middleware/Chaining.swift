import HTTP

extension Middleware {
    func chain(to responder: HTTPResponder) -> HTTPResponder {
        return Request.Handler { request in
            return try self.respond(to: request, chainingTo: responder)
        }
    }
}

extension Collection where Iterator.Element == Middleware {
    func chain(to responder: HTTPResponder) -> HTTPResponder {
        return reversed().reduce(responder) { nextResponder, nextMiddleware in
            return Request.Handler { request in
                return try nextMiddleware.respond(to: request, chainingTo: nextResponder)
            }
        }
    }
}
