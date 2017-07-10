import Cache

extension MemoryCache: Service {
    /// See Service.name
    public var name: String {
        return "memory"
    }

    /// See Service.make()
    public static func make(for drop: Droplet) throws -> MemoryCache? {
        return .init()
    }
}
