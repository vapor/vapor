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
        guard let cost = container.config["bcrypt", "cost"]?.int else {
            throw ConfigError.missing(
                key: ["cost"],
                file: "bcrypt",
                desiredType: UInt.self
            )
        }

        return .init(cost: UInt(cost))
    }
}
