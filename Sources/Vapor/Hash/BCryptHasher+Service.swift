extension BCryptHasher: Service {
    /// See Service.serviceName
    public static var serviceName: String {
        return "bcrypt"
    }

    /// See Service.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [HashProtocol.self]
    }

    /// See Service.make
    public static func makeService(for drop: Droplet) throws -> BCryptHasher? {
        guard let cost = drop.config["bcrypt", "cost"]?.uint else {
            throw ConfigError.missing(
                key: ["cost"],
                file: "bcrypt",
                desiredType: UInt.self
            )
        }

        return .init(cost: cost)
    }
}
