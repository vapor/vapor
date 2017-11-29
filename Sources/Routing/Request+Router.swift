import HTTP

public protocol HasParameterBag {
    /// The parameters accumulated during routing
    /// for this request
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/routing/parameters/#creating-custom-parameters)
    var parameters: ParameterBag { get set }
}
