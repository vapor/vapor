import Vapor

public func boot(_ app: Application) throws {
    let test = try app.makeContainer().wait()
    let routes = try test.make(Routes.self)
    for route in routes.routes {
        let path = route.path.map { $0.description }.joined(separator: "/")
        print("[\(route.method)] /\(path) \(route.requestType) -> \(route.responseType)")
        for (key, val) in route.userInfo {
            print("  - \(key) = \(val)")
        }
    }
}

extension PathComponent: CustomStringConvertible {
    public var description: String {
        switch self {
        case .anything: return ":"
        case .catchall: return "*"
        case .constant(let string): return string
        case .parameter(let string): return ":" + string
        }
    }
}
