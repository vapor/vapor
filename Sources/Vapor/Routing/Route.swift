public final class Route {
    public var method: HTTPMethod
    public var path: [PathComponent]
    public var responder: Responder
    public var requestType: Any.Type
    public var responseType: Any.Type
    
    public var userInfo: [AnyHashable: Any]
    
    public init(
        method: HTTPMethod,
        path: [PathComponent],
        responder: Responder,
        requestType: Any.Type,
        responseType: Any.Type
    ) {
        self.method = method
        self.path = path
        self.responder = responder
        self.requestType = requestType
        self.responseType = responseType
        self.userInfo = [:]
    }
       
    @discardableResult
    public func description(_ string: String) -> Route {
        self.userInfo["description"] = string
        return self
    }
}
