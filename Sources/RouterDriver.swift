import Foundation

public protocol RouterDriver {
    
    func route(request: Request) -> (Request -> Response)?
    func register(method: Request.Method, path: String, handler: (Request -> Response))
    
}