import HTTP

let parameterBagKey = "routing:parameter-bag"

extension Request {
    /// The parameters accumulated during routing
    /// for this request
    public var parameters: ParameterBag {
        get { return extend[parameterBagKey] as? ParameterBag ?? ParameterBag(request: self) }
        set { extend[parameterBagKey] = newValue }
    }
}

