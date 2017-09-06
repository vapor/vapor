import HTTP

let parameterBagKey = "routing:parameter-bag"

extension Router {
    /// Returns an appropriate responder for the supplied
    /// request, if one exists.
    public func route(request: Request) -> Responder? {
        return self.route(request: request, parameters: &request.parameters)
    }
}

extension Request {
    /// The parameters accumulated during routing
    /// for this request
    public var parameters: ParameterBag {
        get { return extend[parameterBagKey] as? ParameterBag ?? ParameterBag() }
        set { extend[parameterBagKey] = newValue }
    }
}

