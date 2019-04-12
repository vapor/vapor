import Vapor

public func app(_ environment: Environment) throws -> Application {
    let app = Application(environment: environment) {
        var s = Services.default()
        try configure(&s)
        return s
    }
    try boot(app)
    return app
}
