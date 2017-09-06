import HTTP
import Core

open class Route : Extendable {
    public var path: [PathComponent]
    public var method: Method
    public var responder: Responder
    
    public var extend = Extend()
    
    public init(method: Method, path: [PathComponent], responder: Responder) {
        self.method = method
        self.path = path
        self.responder = responder
    }
}
