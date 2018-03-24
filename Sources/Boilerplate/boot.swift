import Vapor

public func boot(_ app: Application) throws {
    // your code here

    let router = try app.make(Router.self)
    router.get("asdf") { req in
        return "asdf"
    }
}
