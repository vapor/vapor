/**
    This protocol defines router objects that can be used to relay
    different paths to the application
*/
public protocol RouterDriver {
    func route(_ request: Request) -> (parameters: [String: String], handler: Responder)?
    func register(_ route: Route)
}
