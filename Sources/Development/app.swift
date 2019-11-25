import Vapor
//
//public func app(_ environment: Environment) throws -> Application {
//    var environment = environment
//    try LoggingSystem.bootstrap(from: &environment)
//    let app = Application(environment)
//    try app.loadDotEnv(on: app.eventLoopGroup.next()).wait()
//    try configure(app)
//    return app
//}
