/**
    This protocol defines router objects that can be used to relay
    different paths to the application
*/
public protocol RouterDriver {
    func route(request: Request) -> (parameters: [String: String], handler: Request.Handler)?
    func register(route: Route)
}
