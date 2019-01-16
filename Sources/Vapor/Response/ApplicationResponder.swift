import Routing

/// Vapor's main `Responder` type. Combines configured middleware + router to create a responder.
public struct ApplicationResponder: HTTPResponder {
    private let responder: HTTPResponder
    
    /// Creates a new `ApplicationResponder`.
    public init(
        routes: HTTPRoutes,
        middleware: [HTTPMiddleware] = []
    ) {
        let router = HTTPRoutesResponder(routes: routes)
        self.responder = middleware.makeResponder(chainingTo: router)
    }

    /// See `Responder`.
    public func respond(to req: HTTPRequestContext) -> EventLoopFuture<HTTPResponse> {
        return self.responder.respond(to: req)
    }
}

// MARK: Private

/// Converts a `Router` into a `Responder`.
public struct HTTPRoutesResponder: HTTPResponder {
    private let router: TrieRouter<HTTPResponder>
    private let eventLoop: EventLoop

    /// Creates a new `RouterResponder`.
    public init(routes: HTTPRoutes) {
        let router = TrieRouter(HTTPResponder.self)
        for route in routes.routes {
            let route = Route<HTTPResponder>(
                path: [.constant(route.method.string)] + route.path,
                output: route.responder
            )
            router.register(route: route)
        }
        self.router = router
        self.eventLoop = routes.eventLoop
    }

    /// See `Responder`.
    public func respond(to req: HTTPRequestContext) -> EventLoopFuture<HTTPResponse> {
        guard let responder = self.route(request: req) else {
            return self.eventLoop.makeFailedFuture(error: Abort(.notFound))
        }
        return responder.respond(to: req)
    }
    
    /// See `Router`.
    private func route(request: HTTPRequestContext) -> HTTPResponder? {
        // FIXME: use NIO's underlying uri byte buffer when possible
        // instead of converting to string. `router.route` accepts conforming to `RoutableComponent`
        let path: [Substring] = request.http.urlString
            .split(separator: "?", maxSplits: 1)[0]
            .split(separator: "/")
        return self.router.route(path: [request.http.method.substring] + path, parameters: &request._parameters)
    }
}

extension Substring: RoutableComponent {
    /// See `RoutableComponent`.
    public var routerParameterValue: String { return .init(self) }
    
    /// See `RoutableComponent`.
    public func routerCompare(to buffer: UnsafeRawBufferPointer, options: Set<RouterOption>) -> Bool {
        if count != buffer.count {
            return false
        }
        
        let a = utf8
        let b = buffer.bindMemory(to: UInt8.self)
        
        if options.contains(.caseInsensitive) {
            for i in 0..<a.count {
                if a[a.index(a.startIndex, offsetBy: i)] & 0xdf != b[i] & 0xdf {
                    return false
                }
            }
        } else {
            for i in 0..<a.count {
                if a[a.index(a.startIndex, offsetBy: i)] != b[i] {
                    return false
                }
            }
        }
        
        return true
    }
}

// MARK: Private

extension HTTPMethod {
    /// Converts `HTTPMethod` to a `Substring`.
    var substring: Substring {
        switch self {
        case .GET: return "GET"
        default: return .init(string)
        }
    }
}
