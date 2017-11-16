import HTTP

let parameterBagKey = "routing:parameter-bag"

extension Request {
    /// The parameters accumulated during routing
    /// for this request
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/routing/parameters/#creating-custom-parameters)
    public var parameters: ParameterBag {
        get { return extend[parameterBagKey] as? ParameterBag ?? ParameterBag(request: self) }
        set { extend[parameterBagKey] = newValue }
    }
}

