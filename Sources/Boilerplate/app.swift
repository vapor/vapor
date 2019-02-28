import Vapor

public func app(_ env: Environment) throws -> Application {
    let app = Application(env: env) {
        var s = Services.default()
        try configure(&s)
        return s
    }
    try boot(app)
    return app
}
