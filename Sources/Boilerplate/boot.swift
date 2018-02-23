import Vapor

public func boot(_ app: Application) throws {
    // register routes
    let router = try app.make(Router.self)
    let routes = Routes(app: app)
    try router.register(collection: routes)

    // your code here
}
