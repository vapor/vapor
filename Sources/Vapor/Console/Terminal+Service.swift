import Console
import Service

extension Terminal: ServiceType {
    /// See Service.name
    public static var serviceName: String {
        return "terminal"
    }

    /// See Service.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [ConsoleProtocol.self]
    }

    /// See Service.make()
    public static func makeService(for container: Container) throws -> Terminal? {
        return .init(arguments: container.config.arguments)
    }
}
