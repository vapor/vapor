public protocol LifecycleHandler: Sendable {
    func willBoot(_ application: Application) throws
    func didBoot(_ application: Application) throws
    func shutdown(_ application: Application)
    func willBootAsync(_ application: Application) async throws
    func didBootAsync(_ application: Application) async throws
    func shutdownAsync(_ application: Application) async
}

extension LifecycleHandler {
    public func willBoot(_ application: Application) throws { }
    public func didBoot(_ application: Application) throws { }
    public func shutdown(_ application: Application) { }

    func willBootAsync(_ application: Application) async throws { 
        try self.willBoot(application)
    }
    
    func didBootAsync(_ application: Application) async throws {
        try self.didBoot(application)
    }
    
    func shutdownAsync(_ application: Application) async {
        self.shutdown(application)
    }
}
