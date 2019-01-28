import Vapor

public func app(_ env: Environment) -> Application {
    return Application.init(env: env) {
        var s = Services.default()
        try configure(&s)
        return s
    }
}
