import Async

public struct TypeServiceFactory<S: ServiceType>: ServiceFactory {
    /// See ServiceType.serviceType
    public var serviceType: Any.Type {
        return S.self
    }

    /// See ServiceType.serviceSupports
    public var serviceSupports: [Any.Type] {
        return S.serviceSupports
    }

    /// See ServiceType.serviceTag
    public var serviceTag: String? {
        return nil
    }
    
    /// See ServiceType.makeService
    public func makeService(for worker: Container) throws -> Any? {
        return try S.makeService(for: worker)
    }

    /// Create a new type service factory
    public init(_ s: S.Type = S.self) { }
}
