import Console

extension Terminal: Service {
    /// See Service.name
    public static var name: String {
        return "terminal"
    }

    /// See Service.make()
    public static func make(for drop: Droplet) throws -> Terminal? {
        return .init(arguments: drop.config.arguments)
    }
}
