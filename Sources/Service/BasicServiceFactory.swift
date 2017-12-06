import Async

public struct BasicServiceFactory: ServiceFactory {
    /// See ServiceFactory.serviceType
    public let serviceType: Any.Type

    /// See ServiceFactory.serviceSupports
    public var serviceSupports: [Any.Type]

    /// See ServiceFactory.serviceTag
    public var serviceTag: String?

    /// See ServiceFactory.serviceIsSingleton
    public var serviceIsSingleton: Bool

    /// Accepts a container and worker, returning an
    /// initialized service.
    public typealias ServiceFactoryClosure = (Container) throws -> Any

    /// Closure that constructs the service
    public let closure: ServiceFactoryClosure

    /// Create a new basic service factoryl.
    public init(
        _ type: Any.Type,
        tag: String?,
        supports interfaces: [Any.Type],
        isSingleton: Bool,
        factory closure: @escaping ServiceFactoryClosure
    ) {
        self.serviceType = type
        self.serviceTag = tag
        self.serviceSupports = interfaces
        self.serviceIsSingleton = isSingleton
        self.closure = closure
    }

    /// See ServiceFactory.makeService
    public func makeService(for worker: Container) throws -> Any {
        return try closure(worker)
    }
}
