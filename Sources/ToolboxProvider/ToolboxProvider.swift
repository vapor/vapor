import Logging
import Vapor
import HTTP
import Foundation
import Dispatch

public final class ToolboxProvider: Provider {
    public static var repositoryName = "toolbox-provider"
    private var lock = NSLock()
    private var loggers = [ToolboxLogger]()
    private var middlewares = [ToolboxMiddleware]()
    
    public static let `default` = ToolboxProvider()
    
    public var refreshInterval = DispatchTimeInterval.seconds(10)
    
    public func register(_ services: inout Services) throws {
        services.register(Logger.self) { _ in
            return ToolboxLogger(provider: self)
        }
        
        services.register(ToolboxMiddleware.self) { _ in
            return ToolboxMiddleware(provider: self)
        }
    }
    
    func registerLogger(_ logger: ToolboxLogger) {
        lock.lock()
        defer { lock.unlock() }
        
        self.loggers.append(logger)
    }
    
    func statistics() -> StatisticsResponse {
        return StatisticsResponse(
            messages: self.loggers.map { $0.drainMessages() },
            routeStatistics: self.middlewares.map { $0.drainStatistics() }
        )
    }
    
    func registerMiddleware(_ middleware: ToolboxMiddleware) {
        lock.lock()
        defer { lock.unlock() }
        
        self.middlewares.append(middleware)
    }
    
    public func boot(_ worker: Container) throws {}
}

extension Router {
    public func statistics(_ route: PathComponentRepresentable...) {
        let path = route.map { $0.makePathComponent() }
        
        self.on(HTTPMethod.get, to: path) { request in
            return ToolboxProvider.default.statistics()
        }
    }
}

public struct StatisticsResponse: Content {
    public typealias WorkerMessages = [LogMessage]
    public typealias MiddlewareStatistics = [RouteStatistics]
    
    public var messages: [WorkerMessages]
    public var routeStatistics: [MiddlewareStatistics]
}
