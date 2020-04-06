import NIO

public protocol LifecycleHandler {
    func didRegister(_ application: Application)
    func willBoot(_ application: Application) throws
    func didBoot(_ application: Application) throws
    func shutdown(_ application: Application)
}

extension LifecycleHandler {
    public func didRegister(_ application: Application) { }
    public func willBoot(_ application: Application) throws { }
    public func didBoot(_ application: Application) throws { }
    public func shutdown(_ application: Application) { }
}
