public struct TypeServiceFactory<S: ServiceType>: ServiceFactory {
    public var serviceType: Any.Type {
        return S.self
    }

    public var serviceIsSingleton: Bool {
        return S.serviceIsSingleton
    }

    public var serviceSupports: [Any.Type] {
        return S.serviceSupports
    }

    public var serviceTag: String? {
        return nil
    }

    public func makeService(for context: Context) throws -> Any? {
        return try S.makeService(for: context)
    }

    public init(_ s: S.Type = S.self) { }
}
