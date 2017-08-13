import Console
import Service

extension Terminal: ServiceType {
    /// See Service.name
    public static var serviceName: String {
        return "terminal"
    }

    /// See Service.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [Console.self]
    }

    /// See Service.make()
    public static func makeService(for container: Container) throws -> Terminal? {
        return Terminal()
    }
}
