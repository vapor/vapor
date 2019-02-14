//public protocol Application {
//    var env: Environment { get }
//
//    var eventLoopGroup: EventLoopGroup { get }
//
//    var userInfo: [AnyHashable: Any] { get set }
//
//    init(env: Environment)
//
//    func makeServices() throws -> Services
//
//    func cleanup() throws
//}
import Foundation

public final class Application {
    public let env: Environment
    
    public let eventLoopGroup: EventLoopGroup
    
    public var userInfo: [AnyHashable: Any]
    
    public let lock: NSLock
    
    private let configure: () throws -> Services
    
    private let threadPool: BlockingIOThreadPool
    
    private var didCleanup: Bool
    
    public init(env: Environment = .development, configure: @escaping () throws -> Services) {
        self.env = env
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.userInfo = [:]
        self.didCleanup = false
        self.configure = configure
        self.lock = NSLock()
        self.threadPool = .init(numberOfThreads: 1)
        self.threadPool.start()
    }
    
    public func makeContainer() -> EventLoopFuture<Container> {
        return self.makeContainer(on: self.eventLoopGroup.next())
    }
    
    public func makeContainer(on eventLoop: EventLoop) -> EventLoopFuture<Container> {
        do {
            return try _makeContainer(on: eventLoop)
        } catch {
            return eventLoopGroup.next().makeFailedFuture(error)
        }
    }
    
    private func _makeContainer(on eventLoop: EventLoop) throws -> EventLoopFuture<Container> {
        var services = try self.configure()
        services.register(Application.self) { c in
            return self
        }
        let container = BasicContainer(environment: self.env, services: services, on: eventLoop)
        #warning("TODO: make willBoot and didBoot non-throwing")
        let willBoots = container.providers.map { try! $0.willBoot(container) }
        return EventLoopFuture<Void>.andAllSucceed(willBoots, on: eventLoop).flatMap { () -> EventLoopFuture<Void> in
            let didBoots = container.providers.map { try! $0.didBoot(container) }
            return .andAllSucceed(didBoots, on: eventLoop)
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
    public func run() -> EventLoopFuture<Application> {
        let eventLoop = self.eventLoopGroup.next()
        #warning("TODO: run VaporProvider willRuns")
        return self.loadDotEnv(on: eventLoop).flatMap {
            return self.makeContainer(on: eventLoop)
        }.flatMapThrowing { c -> (Console, CommandGroup) in
            let command = try c.make(Commands.self).group()
            let console = try c.make(Console.self)
            return (console, command)
        }.flatMap { res -> EventLoopFuture<Void> in
            var runInput = self.env.commandInput
            return res.0.run(res.1, input: &runInput)
        }.map {
            return self
        }
//        // will-run all vapor service providers
//        return try self.providers.onlyVapor.map { try $0.willRun(self) }.flatten(on: self)
//        // did-run all vapor service providers
//        return try self.providers.onlyVapor.map { try $0.didRun(self) }.flatten(on: self)
    }
    
    private func loadDotEnv(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        return DotEnvFile.load(
            path: ".env",
            fileio: .init(threadPool: self.threadPool),
            on: eventLoop
        ).recover { error in
            print("Could not load .env file: \(error)")
        }
    }
    
    public func cleanup() throws {
        try self.eventLoopGroup.syncShutdownGracefully()
        try self.threadPool.syncShutdownGracefully()
        self.didCleanup = true
        
    }
    
    deinit {
        if !self.didCleanup {
            assertionFailure("Application.cleanup() was not called before Application deinitialized.")
        }
    }
}
