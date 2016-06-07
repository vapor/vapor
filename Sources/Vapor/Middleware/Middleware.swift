/**
    Intercepts requests and responses
    to add functionality in a package that 
    can be easily added or removed from an application.
*/
public protocol Middleware {
    func handle(_ handler: Request.Handler) -> Request.Handler
}
