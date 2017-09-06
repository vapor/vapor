import HTTP

/// Routes requests to an appropriate responder.
public protocol Router: class {
    /// Register a responder at a given array of path components.
    /// Some path components may be dynamic.
    func register(route: Route)

    /// Route the supplied path to a responder, filling the parameters
    /// bag with found dynamic parameters.
    func route(request: Request, parameters: inout ParameterBag) -> Responder?
}
