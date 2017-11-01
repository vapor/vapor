import HTTP

let parameterBagKey = "routing:parameter-bag"

extension Request {
    /// The parameters accumulated during routing
    /// for this request
    ///
    /// http://localhost:8000/routing/parameters/#creating-custom-parameters
    public var parameters: ParameterBag {
        get { return extend[parameterBagKey] as? ParameterBag ?? ParameterBag(request: self) }
        set { extend[parameterBagKey] = newValue }
    }
}

