import Vapor

public func app(_ environment: Environment) throws -> Application {
    let app = Application(environment: environment)
    try configure(app)
    try boot(app)
    return app
}
