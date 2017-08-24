public struct BasicServiceFactory: ServiceFactory {
    public typealias ServiceFactoryClosure = (Container) throws -> Any?

    public let serviceType: Any.Type
    public let serviceIsSingleton: Bool
    public var serviceSupports: [Any.Type]
    public var serviceTag: String?

    public let closure: ServiceFactoryClosure

    public init(
        _ type: Any.Type,
        tag: String? = nil,
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

    public func makeService(for container: Container) throws -> Any? {
        return try closure(container)
    }
}
