public struct Core: Provider {
    public init() { }
    
    public func register(_ app: Application) {
        app.core = CoreStorage(app)
    }
    
    public func willShutdown(_ app: Application) {
        app.core.shutdown()
    }
}
