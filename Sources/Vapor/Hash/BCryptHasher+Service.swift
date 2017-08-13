import Service

extension BCryptHasher: ServiceType {
    /// See Service.serviceName
    public static var serviceName: String {
        return "bcrypt"
    }

    /// See Service.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [HashProtocol.self]
    }

    /// See Service.make
    public static func makeService(for container: Container) throws -> BCryptHasher? {
        return try BCryptHasher(config: container.make())
    }
}
