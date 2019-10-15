import NIO

public protocol Provider {
    func register(_ s: inout Services)

    func willBoot(_ app: Application) throws
    func didBoot(_ app: Application) throws
    func willShutdown(_ app: Application)

    func willBoot(_ c: Container) throws
    func didBoot(_ c: Container) throws
    func willShutdown(_ c: Container)
}

extension Provider {
    public func willBoot(_ app: Application) throws { }
    public func didBoot(_ app: Application) throws { }
    public func willShutdown(_ app: Application) { }

    public func willBoot(_ c: Container) throws { }
    public func didBoot(_ c: Container) throws { }
    public func willShutdown(_ c: Container) { }
}
