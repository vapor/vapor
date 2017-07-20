public protocol ServiceFactory {
    var serviceType: Any.Type { get }
    var serviceName: String { get }
    var serviceIsSingleton: Bool { get }
    func makeService(for drop: Droplet) throws -> Any?
}
