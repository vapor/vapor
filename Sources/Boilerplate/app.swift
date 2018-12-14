import Vapor

public func app(_ env: Environment) throws -> Application {
    return try Application(env) {
        var s = Services.default()
        try configure(&s)
        return s
    }
}
