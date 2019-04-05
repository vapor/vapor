import NIO

public final class Application {
    public let env: Environment
    
    public let eventLoopGroup: EventLoopGroup
    
    public var userInfo: [AnyHashable: Any]
    
    public let lock: NSLock
    
    private let configure: () throws -> Services
    
    private let threadPool: NIOThreadPool
    
    private var didShutdown: Bool
    
    public var running: Running?
    
    public struct Running {
        public var stop: () throws -> Void
        public init(stop: @escaping () throws -> Void) {
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
        var s = try self.configure()
        s.register(Application.self) { c in
            return self
        }
        s.register(NIOThreadPool.self) { c in
            return self.threadPool
        }
        return s
    }
    
    public func makeContainer() -> EventLoopFuture<Container> {
        return self.makeContainer(on: self.eventLoopGroup.next())
    }
    
    public func makeContainer(on eventLoop: EventLoop) -> EventLoopFuture<Container> {
        do {
            return try _makeContainer(on: eventLoop)
        } catch {
            return self.eventLoopGroup.next().makeFailedFuture(error)
        }
    }
    
    private func _makeContainer(on eventLoop: EventLoop) throws -> EventLoopFuture<Container> {
        let s = try self._makeServices()
        return Container.boot(env: self.env, services: s, on: eventLoop)
    }

    // MARK: Run
    
    public func run() throws {
        defer { self.shutdown() }
        try self.runCommands()
    }
    
    public func runCommands() throws {
        let eventLoop = self.eventLoopGroup.next()
        try self.loadDotEnv(on: eventLoop).wait()
        let c = try self.makeContainer(on: eventLoop).wait()
        defer { c.shutdown() }
        let command = try c.make(Commands.self).group()
        let console = try c.make(Console.self)
        var runInput = self.env.commandInput
        try console.run(command, input: &runInput)
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
    
    public func shutdown() {
        print("Application shutting down")
        do {
            try self.eventLoopGroup.syncShutdownGracefully()
        } catch {
            print("EventLoopGroup failed to shutdown: \(error)")
        }
        do {
            try self.threadPool.syncShutdownGracefully()
        } catch {
            print("ThreadPool failed to shutdown: \(error)")
        }
        self.didShutdown = true
        self.userInfo = [:]
    }
    
    deinit {
        if !self.didShutdown {
            assertionFailure("Application.shutdown() was not called before Application deinitialized.")
        }
    }
}
