import HTTP

/// Routes requests to an appropriate responder.
public protocol Router: class {
    func register(responder: Responder, path: [String])
    func route(request: Request) -> Responder?
}

extension Router {
    /// Registers a route handler at the supplied path.
    public func get(_ path: String..., closure: @escaping BasicResponder.Closure) {
        let responder = BasicResponder(closure: closure)
        self.register(responder: responder, path: path)
    }
}

// MARK: Utility

/// A basic, closure-based responder.
public struct BasicResponder: Responder {
    /// Responder closure
    public typealias Closure = (Request, ResponseWriter) throws -> ()

    /// The stored responder closure.
    public let closure: Closure

    /// Create a new basic responder.
    public init(closure: @escaping Closure) {
        self.closure = closure
    }

    /// See: HTTP.Responder.respond
    public func respond(to req: Request, using writer: ResponseWriter) throws {
        try closure(req, writer)
    }
}
