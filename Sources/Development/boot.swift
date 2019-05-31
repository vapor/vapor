import Vapor

public func boot(_ app: Application) throws {
    let c = try app.makeContainer().wait()
    defer { c.shutdown() }
    
    // bootstrap logging system
    let console = try c.make(Console.self)
    LoggingSystem.bootstrap(
        console: console,
        level: app.environment == .production ? .error : .info
    )
    
    // use container
}
