import Vapor
import Foundation

public final class ToolboxMiddleware: Middleware {
    private var statistics = [RouteStatistics]()
    private var lock = NSLock()
    
    public init(provider: ToolboxProvider) {
        provider.registerMiddleware(self)
    }
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        let date = Date()
        
        return try next.respond(to: request).map { response -> Response in
            self.lock.lock()
            defer { self.lock.unlock() }
            
            let responseTime = Date().timeIntervalSince(date)
            
            let routeStats = RouteStatistics(
                method: request.http.method,
                uri: request.http.uri,
                responseTime: responseTime
            )
            
            self.statistics.append(routeStats)
            
            return response
        }
    }
    
    func drainStatistics() -> [RouteStatistics] {
        self.lock.lock()
        defer { self.lock.unlock() }
        
        let statistics = self.statistics
        self.statistics = []
        
        return statistics
    }
}

public struct RouteStatistics: Codable {
    public var method: HTTPMethod
    public var uri: URI
    public var responseTime: TimeInterval
}
