import Caches
import Service

extension MemoryCache: ServiceType {
    /// See Service.name
    public var serviceName: String {
        return "memory"
    }

    public static var serviceSupports: [Any.Type] {
        return [CacheProtocol.self]
    }

    /// See Service.make()
    public static func makeService(for container: Container) throws -> MemoryCache? {
        return .init()
    }
}
