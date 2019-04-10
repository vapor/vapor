import NIO

/// `Provider`s allow third-party services to be easily integrated into a service `Container`.
///
/// Simply register the `Provider` like any other service and it will take care of setting up any necessary
/// configurations on itself and the container.
///
///     services.register(RedisProvider())
///
/// # Lifecycle
///
/// `Provider`s have two phases:
///
/// - Registration
/// - Boot
///
/// ## Registration
///
/// During the registration phase, the `Provider` is supplied with a mutable `Services` struct. The `Provider`
/// is expected to register all services it would like to expose to the `Container` during this phase.
///
///     services.register(RedisCache.self)
///
/// ## Boot
///
/// There are two parts of the boot phase: `willBoot(_:)` and `didBoot(_:)`. Both of these methods supply
/// the `Provider` with access to the initialized `Container` and allow asynchronous work to be done.
///
/// The `didBoot(_:)` method is guaranteed to be called after all providers have run `willBoot(_:)`. Most providers should
/// try to do their work in the `didBoot(_:)` method, resorting to the `willBoot(_:)` method if they want to pre-empt work
/// done by other providers.
public protocol Provider {
    /// Register all services you would like to provide the `Container` here.
    ///
    ///     services.register(RedisCache.self)
    ///
    func register(_ s: inout Services) throws

    /// Called before the container has fully initialized.
    func willBoot(_ c: Container) -> EventLoopFuture<Void>

    /// Called after the container has fully initialized and after `willBoot(_:)`.
    func didBoot(_ c: Container) -> EventLoopFuture<Void>
    
    /// Called before the container shuts down.
    func willShutdown(_ c: Container)
}

extension Provider {
    /// Default implementation.
    public func willBoot(_ c: Container) -> EventLoopFuture<Void> {
        return c.eventLoop.makeSucceededFuture(())
    }
    
    /// Default implementation.
    public func didBoot(_ c: Container) -> EventLoopFuture<Void> {
        return c.eventLoop.makeSucceededFuture(())
    }
    
    /// Default implementation.
    public func willShutdown(_ c: Container) { }
}
