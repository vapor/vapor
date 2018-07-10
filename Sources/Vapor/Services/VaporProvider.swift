/// A normal service `Provider` extended with additional life-cycle hooks for Vapor-specific containers.
public protocol VaporProvider: Provider {
    /// Called before the application runs commands.
    func willRun(_ worker: Container) throws -> Future<Void>

    /// Called after the application has finished running.
    /// - note: This may never happen if the server runs infinitely.
    func didRun(_ worker: Container) throws -> Future<Void>
}

extension Array where Element == Provider {
    /// Returns only the `VaporProvider` service providers.
    internal var onlyVapor: [VaporProvider] {
        return compactMap { $0 as? VaporProvider }
    }
}
