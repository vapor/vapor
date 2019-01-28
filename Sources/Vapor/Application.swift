public protocol Application {
    var env: Environment { get }
    
    var eventLoopGroup: EventLoopGroup { get }
    
    var userInfo: [AnyHashable: Any] { get set }
    
    init(env: Environment)
    
    func makeServices() throws -> Services
    
    func cleanup() throws
}

extension Application {
    public func makeContainer() -> EventLoopFuture<Container> {
        return self.makeContainer(on: self.eventLoopGroup.next())
    }
    
    public func cleanup() throws {
        print("Cleaning up application...")
        try self.eventLoopGroup.syncShutdownGracefully()
    }
    
    public func makeContainer(on eventLoop: EventLoop) -> EventLoopFuture<Container> {
        do {
            return try _makeContainer(on: eventLoop)
        } catch {
            return eventLoopGroup.next().makeFailedFuture(error)
        }
    }
    
    private func _makeContainer(on eventLoop: EventLoop) throws -> EventLoopFuture<Container> {
        var services = try self.makeServices()
        services.register(Application.self) { c in
            return self
        }
        let container = BasicContainer(environment: self.env, services: services, on: eventLoop)
        #warning("TODO: make willBoot and didBoot non-throwing")
        let willBoots = container.providers.map { try! $0.willBoot(container) }
        return EventLoopFuture<Void>.andAll(willBoots, eventLoop: eventLoop).flatMap { () -> EventLoopFuture<Void> in
            let didBoots = container.providers.map { try! $0.didBoot(container) }
            return .andAll(didBoots, eventLoop: eventLoop)
        }.map { _ in container }
    }

    // MARK: Run

    /// Asynchronously runs the `Application`'s commands. This method will call the `willRun(_:)` methods of all
    /// registered `VaporProvider's` before running.
    ///
    /// Normally this command will boot an `HTTPServer`. However, depending on configuration and command-line arguments/flags, this method may run a different command.
    /// See `CommandConfig` for more information about customizing the commands that this method runs.
    ///
    ///     try app.run().wait()
    ///
    /// Note: When running a server, `asyncRun()` will return when the server has finished _booting_. Use the `runningServer` property on `Application` to wait
    /// for the server to close. The synchronous `run()` method will call this automatically.
    ///
    ///     try app.runningServer?.onClose().wait()
    ///
    /// All `VaporProvider`'s `didRun(_:)` methods will be called before finishing.
    public func run() -> EventLoopFuture<Void> {
        if _isDebugAssertConfiguration() && self.env.isRelease {
            print("Debug build mode detected while configured for release environment: \(self.env.name).")
            print("Compile your application with `-c release` to enable code optimizations.")
        }
        
        #warning("TODO: run VaporProvider willRuns")
        return self.makeContainer().flatMapThrowing { c -> (Console, CommandGroup) in
            let command = try c.make(Commands.self).group()
            let console = try c.make(Console.self)
            return (console, command)
        }.flatMap { res -> EventLoopFuture<Void> in
            var runInput = self.env.commandInput
            return res.0.run(res.1, input: &runInput)
        }
//        // will-run all vapor service providers
//        return try self.providers.onlyVapor.map { try $0.willRun(self) }.flatten(on: self)
//        // did-run all vapor service providers
//        return try self.providers.onlyVapor.map { try $0.didRun(self) }.flatten(on: self)
    }
}
