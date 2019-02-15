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
    
    private var didShutdown: Bool
    
    public var running: Running?
    
    public struct Running {
        public var stop: () -> Void
        public init(stop: @escaping () -> Void) {
            self.stop = stop
        }
    }
    
    public final class Worker: Container {
        public var environment: Environment
        
        public var services: Services
        
        public var cache: ServiceCache
        
        public var eventLoop: EventLoop
        
        init(env: Environment, services: Services, on eventLoop: EventLoop) {
            // print("Worker++")
            self.environment = env
            self.services = services
            self.eventLoop = eventLoop
            self.cache = .init()
        }
        
        deinit {
            // print("Worker--")
        }
    }
    
    public init(env: Environment = .development, configure: @escaping () throws -> Services) {
        self.env = env
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.userInfo = [:]
        self.didShutdown = false
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
        let container = Worker(
            env: self.env,
            services: services,
            on: eventLoop
        )
        return container.willBoot()
            .flatMap { container.didBoot() }
            .map { container }
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
        let eventLoop = self.eventLoopGroup.next()
        return self.loadDotEnv(on: eventLoop).flatMap {
            return self.makeContainer(on: eventLoop)
        }.flatMapThrowing { c -> (Console, CommandGroup, Container) in
            let command = try c.make(Commands.self).group()
            let console = try c.make(Console.self)
            return (console, command, c)
        }.flatMap { res -> EventLoopFuture<Void> in
            let (console, command, c) = res
            var runInput = self.env.commandInput
            return console.run(command, input: &runInput).flatMap {
                return c.willShutdown()
            }
        }
    }
    
    public func execute() -> EventLoopFuture<Void> {
        return self.run().flatMapThrowing { _ in
            try self.shutdown()
        }.flatMapErrorThrowing { error in
            try self.shutdown()
            throw error
        }
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
    
    public func shutdown() throws {
        print("Application shutting down")
        try self.eventLoopGroup.syncShutdownGracefully()
        try self.threadPool.syncShutdownGracefully()
        self.didShutdown = true

    }
    
    deinit {
        if !self.didShutdown {
            assertionFailure("Application.shutdown() was not called before Application deinitialized.")
        }
    }
}
