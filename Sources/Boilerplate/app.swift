import Vapor

public final class BoilerplateApp: Application {
    public var env: Environment
    
    public var eventLoopGroup: EventLoopGroup
    
    public var userInfo: [AnyHashable : Any]
    
    public init(env: Environment) {
        self.env = env
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.userInfo = [:]
    }
    
    public func makeServices() throws -> Services {
        var s = Services.default()
        try configure(&s)
        return s
    }
}
