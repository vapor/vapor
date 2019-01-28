/// A normal service `Provider` extended with additional life-cycle hooks for Vapor-specific containers.
public protocol VaporProvider: ServiceProvider {
    /// Called before the application runs commands.
    func willRun(_ worker: Container) throws -> EventLoopFuture<Void>

    /// Called after the application has finished running.
    /// - note: This may never happen if the server runs infinitely.
    func didRun(_ worker: Container) throws -> EventLoopFuture<Void>
}

extension Array where Element == ServiceProvider {
    /// Returns only the `VaporProvider` service providers.
    internal var onlyVapor: [VaporProvider] {
        return compactMap { $0 as? VaporProvider }
    }
}
