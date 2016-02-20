import Foundation

public protocol RouterDriver {
    func route(request: Request) -> RequestHandler?
    func register(hostname hostname: String, method: Request.Method, path: String, handler: RequestHandler)
}
