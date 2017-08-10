import Console
import Service

extension ConsoleLogger: ServiceType {
    /// See Service.name
    public static var serviceName: String {
        return "console"
    }

    /// See Service.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [LogProtocol.self]
    }

    /// See Service.make
    public static func makeService(for container: Container) throws -> ConsoleLogger? {
        return try .init(container.make(ConsoleProtocol.self))
    }
}
