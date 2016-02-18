import Foundation

public protocol RouterDriver {
    
    func route(request: Request) -> (Request -> Response)?
    func register(hostname hostname: String?, method: Request.Method, path: String, handler: (Request -> Response))
    
}