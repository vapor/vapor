import Console

extension Terminal: Service {
    /// See Service.name
    public static var serviceName: String {
        return "terminal"
    }

    /// See Service.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [ConsoleProtocol.self]
    }

    /// See Service.make()
    public static func makeService(for drop: Droplet) throws -> Terminal? {
        return .init(arguments: drop.config.arguments)
    }
}
