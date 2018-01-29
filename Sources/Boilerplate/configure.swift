import Vapor
import Foundation

public func configure(
    _ config: inout Config,
    _ env: inout Environment,
    _ services: inout Services
) throws {
    // configure your application here
    var middlewareConfig = MiddlewareConfig()
    //middlewareConfig.use(DateMiddleware.self)
    services.register(middlewareConfig)
}
