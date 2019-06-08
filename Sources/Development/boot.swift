import Vapor

public func boot(_ app: Application) throws {
    try LoggingSystem.bootstrap(from: &app.environment)
    try app.boot()
}
