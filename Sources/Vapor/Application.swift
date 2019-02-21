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
    
    public func _makeServices() throws -> Services {
        return try self.configure()
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
        var s = try self.configure()
        s.register(Application.self) { c in
            return self
        }
        return Container.boot(env: self.env, services: s, on: eventLoop)
    }

    // MARK: Run

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
                return c.shutdown()
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
