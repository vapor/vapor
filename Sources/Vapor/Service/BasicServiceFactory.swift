public struct BasicServiceFactory: ServiceFactory {
    public typealias ServiceFactoryClosure = (Droplet) throws -> Any?

    public let serviceType: Any.Type
    public let serviceName: String
    public let serviceIsSingleton: Bool
    public var serviceSupports: [Any.Type]

    public let closure: ServiceFactoryClosure

    public init(
        _ serviceType: Any.Type,
        name: String,
        supports: [Any.Type],
        isSingleton: Bool,
        factory closure: @escaping ServiceFactoryClosure
    ) {
        self.serviceType = serviceType
        self.serviceName = name
        self.serviceSupports = supports
        self.serviceIsSingleton = isSingleton
        self.closure = closure
    }

    public func makeService(for drop: Droplet) throws -> Any? {
        return try closure(drop)
    }
}
