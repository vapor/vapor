import HTTP

open class Route {
    public var path: [PathComponent]
    public var method: Method
    public var responder: Responder
    
    public init(method: Method, path: [PathComponent], responder: Responder) {
        self.method = method
        self.path = path
        self.responder = responder
    }
}
