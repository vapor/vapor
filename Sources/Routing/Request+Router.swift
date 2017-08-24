import HTTP

let parameterBagKey = "routing:parameter-bag"

extension Router {
    /// Returns an appropriate responder for the supplied
    /// request, if one exists.
    public func route(request: Request) -> Responder? {
        let path = [request.method.string] + request.uri.path.split(separator: "/").map(String.init)
        return self.route(path: path, parameters: &request.parameters)
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

