import Async

public protocol ServiceFactory {
    /// This services type. Used for looking up
    /// the service.
    var serviceType: Any.Type { get }

    /// An array of protocols that this service supports.
    /// Note: this service _must_ be force-castable to all
    /// interfaces provided in this array.
    var serviceSupports: [Any.Type] { get }

    /// Unique tag for this service, to differentiate
    /// it from identical service types.
    var serviceTag: String? { get }

    /// Creates an instance of the service for the supplied
    /// container and worker
    func makeService(for container: Container) throws -> Any?
}
