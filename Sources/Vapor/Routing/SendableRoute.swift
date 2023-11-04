import NIOHTTP1
@preconcurrency import RoutingKit
import NIOConcurrencyHelpers

public struct SendableRoute: CustomStringConvertible, Sendable {
    public var method: HTTPMethod
    public var path: [PathComponent]
    public var responder: Responder
    public var requestType: Any.Type
    public var responseType: Any.Type
    public var userInfo: [String: Sendable]
    
    public var description: String {
        let path = path.map { "\($0)" }.joined(separator: "/")
        return "\(method.string) /\(path)"
    }
        
    public init(
        method: HTTPMethod,
        path: [PathComponent],
        responder: Responder,
        requestType: Any.Type,
        responseType: Any.Type
    ) {
        self.method = method
        self.path = path
        self.responder = responder
        self.requestType = requestType
        self.responseType = responseType
        self.userInfo = [:]
    }
       
    @discardableResult
    public mutating func description(_ string: String) -> SendableRoute {
        self.userInfo["description"] = string
        return self
    }
}
