/// Provides a way to hook into lifecycle events of a Vapor application. You can register
/// your handlers with the ``Application`` to be notified when the application
/// is about to start up, has started up and is about to shutdown
///
/// For example
/// ```swift
///  struct LifecycleLogger: LifecycleHander {
///    func willBootAsync(_ application: Application) async throws {
///        application.logger.info("Application about to boot up")
///    }
///
///    func didBootAsync(_ application: Application) async throws {
///        application.logger.info("Application has booted up")
///    }
///
///    func shutdownAsync(_ application: Application) async {
///        application.logger.info("Will shutdown")
///    }
///  }
/// ```
///
/// You can then register your handler with the application:
///
/// ```swift
/// application.lifecycle.use(LifecycleLogger())
/// ```
///
public protocol LifecycleHandler: Sendable {
    /// Called when the application is about to boot up
    func willBoot(_ application: Application) throws
    /// Called when the application has booted up
    func didBoot(_ application: Application) throws
    /// Called when the application is about to shutdown
    func shutdown(_ application: Application)
    /// Called when the application is about to boot up. This is the asynchronous version
    /// of ``willBoot(_:)-9zn``.
    /// **Note** your application must be running in an asynchronous context and initialised with
    /// ``Application/make(_:_:)`` for this handler to be called
    func willBootAsync(_ application: Application) async throws
    /// Called when the application is about to boot up. This is the asynchronous version
    /// of ``didBoot(_:)-wfef``.
    /// **Note** your application must be running in an asynchronous context and initialised with
    /// ``Application/make(_:_:)`` for this handler to be called
    func didBootAsync(_ application: Application) async throws
    /// Called when the application is about to boot up. This is the asynchronous version
    /// of ``shutdown(_:)-2clwm``.
    /// **Note** your application must be running in an asynchronous context and initialised with
    /// ``Application/make(_:_:)`` for this handler to be called
    func shutdownAsync(_ application: Application) async
}

extension LifecycleHandler {
    public func willBoot(_ application: Application) throws { }
    public func didBoot(_ application: Application) throws { }
    public func shutdown(_ application: Application) { }

    public func willBootAsync(_ application: Application) async throws {
        try self.willBoot(application)
    }
    
    public func didBootAsync(_ application: Application) async throws {
        try self.didBoot(application)
    }
    
    public func shutdownAsync(_ application: Application) async {
        self.shutdown(application)
    }
}
