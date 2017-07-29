import Cache

extension MemoryCache: Service {
    /// See Service.name
    public var serviceName: String {
        return "memory"
    }

    public static var serviceSupports: [Any.Type] {
        return [CacheProtocol.self]
    }

    /// See Service.make()
    public static func makeService(for drop: Droplet) throws -> MemoryCache? {
        return .init()
    }
}
