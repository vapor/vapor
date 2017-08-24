import HTTP

/// Routes requests to an appropriate responder.
public protocol Router: class {
    /// Register a responder at a given array of path components.
    /// Somne path components may be dynamic.
    func register(responder: Responder, at path: [PathComponent])

    /// Route the supplied path to a responder, filling the parameters
    /// bag with found dynamic parameters.
    func route(path: [String], parameters: inout ParameterBag) -> Responder?
}
