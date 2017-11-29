//import Async
//
///// Capable of transforming requests and responses.
/////
///// [Learn More →](https://docs.vapor.codes/3.0/http/middleware/)
//public protocol HTTPMiddleware {
//    func respond(to request: HTTPRequest, chainingTo next: HTTPResponder) throws -> Future<HTTPResponse>
//}
//
//// MARK: Responder
//
///// A wrapper that applies the supplied middleware to a responder.
/////
///// Note: internal since it is exposed through `makeResponder` extensions.
//internal final class HTTPMiddlewareResponder: HTTPResponder {
//    /// The middleware to apply.
//    let middleware: HTTPMiddleware
//
//    /// The actual responder.
//    let chained: HTTPResponder
//
//    /// Creates a new middleware responder.
//    init(middleware: HTTPMiddleware, chained: HTTPResponder) {
//        self.middleware = middleware
//        self.chained = chained
//    }
//
//    /// Responder conformance.
//    func respond(to req: HTTPRequest) throws -> Future<HTTPResponse> {
//        return try middleware.respond(to: req, chainingTo: chained)
//    }
//}
//
//
//// MARK: Convenience
//
//extension HTTPMiddleware {
//    /// Converts a middleware into a responder by chaining it to an actual responder.
//    public func makeResponder(chainedTo responder: HTTPResponder) -> HTTPResponder {
//        return HTTPMiddlewareResponder(middleware: self, chained: responder)
//    }
//}
//
///// Extension on [Middleware]
//extension Array where Element == HTTPMiddleware {
//    /// Converts an array of middleware into a responder by
//    /// chaining them to an actual responder.
//    public func makeResponder(chainedto responder: HTTPResponder) -> HTTPResponder {
//        var responder = responder
//        for middleware in self {
//            responder = middleware.makeResponder(chainedTo: responder)
//        }
//        return responder
//    }
//}
//
///// Extension on [ConcreteMiddleware]
//extension Array where Element: HTTPMiddleware {
//    /// Converts an array of middleware into a responder by
//    /// chaining them to an actual responder.
//    public func makeResponder(chainedto responder: HTTPResponder) -> HTTPResponder {
//        var responder = responder
//        for middleware in self {
//            responder = middleware.makeResponder(chainedTo: responder)
//        }
//        return responder
//    }
//}

