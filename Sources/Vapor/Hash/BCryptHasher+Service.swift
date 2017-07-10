extension BCryptHasher: Service {
    /// See Service.name
    public static var name: String {
        return "bcrypt"
    }

    /// See Service.make
    public static func make(for drop: Droplet) throws -> BCryptHasher? {
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
