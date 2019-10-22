import NIO

public protocol Provider {
    func register(_ app: Application)
    func willBoot(_ app: Application) throws
    func didBoot(_ app: Application) throws
    func willShutdown(_ app: Application)
}

extension Provider {
    public func willBoot(_ app: Application) throws { }
    public func didBoot(_ app: Application) throws { }
    public func willShutdown(_ app: Application) { }
}
