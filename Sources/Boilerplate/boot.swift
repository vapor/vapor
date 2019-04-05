import Vapor

public func boot(_ app: Application) throws {
    let test = try app.makeContainer().wait()
    defer { test.shutdown() }
    let routes = try test.make(Routes.self)
    for route in routes.routes {
        let path = route.path.map { $0.description }.joined(separator: "/")
        print("[\(route.method)] /\(path) \(route.requestType) -> \(route.responseType)")
        for (key, val) in route.userInfo {
            print("  - \(key) = \(val)")
        }
    }
}
