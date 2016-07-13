/**
    This protocol defines router objects that can be used to relay
    different paths to the droplet
*/
public protocol Router {
    func route(_ request: Request) -> Responder?
    func register(_ route: Route)
}
