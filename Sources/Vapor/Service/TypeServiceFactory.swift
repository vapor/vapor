public struct TypeServiceFactory<S: Service>: ServiceFactory {
    public var serviceType: Any.Type {
        return S.self
    }

    public var serviceName: String {
        return S.serviceName
    }

    public var serviceIsSingleton: Bool {
        return S.serviceIsSingleton
    }

    public func makeService(for drop: Droplet) throws -> Any? {
        return try S.makeService(for: drop)
    }

    public init(_ s: S.Type = S.self) { }
}
