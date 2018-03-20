import Async
import Bits
import Foundation
//import HTTP
import Routing

/// Groups collections of routes together for adding
/// to a router.
public protocol RouteCollection {
    /// Registers routes to the incoming router.
    func boot(router: Router) throws
}
extension Router {
    /// Registers all of the routes in the group
    /// to this router.
    public func register(collection: RouteCollection) throws {
        try collection.boot(router: self)
    }
}
