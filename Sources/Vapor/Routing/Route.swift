import NIOHTTP1
@preconcurrency import RoutingKit
import NIOConcurrencyHelpers

public final class Route: CustomStringConvertible, Sendable {
    public var method: HTTPMethod {
        get {
            self.sendableBox.withLockedValue { $0.method }
        }
        set {
            self.sendableBox.withLockedValue { $0.method = newValue }
        }
    }
    
    public var path: [PathComponent] {
        get {
            self.sendableBox.withLockedValue { $0.path }
        }
        set {
            self.sendableBox.withLockedValue { $0.path = newValue }
        }
    }
    
    public var responder: Responder {
        get {
            self.sendableBox.withLockedValue { $0.responder }
        }
        set {
            self.sendableBox.withLockedValue { $0.responder = newValue }
        }
    }
    
    public var requestType: Any.Type
    public var responseType: Any.Type
    
    struct SendableBox: Sendable {
        var method: HTTPMethod
        var path: [PathComponent]
        var responder: Responder
    }
    
    public var userInfo: [AnyHashable: Any]

    public var description: String {
        let box = self.sendableBox.withLockedValue { $0 }
        let path = box.path.map { "\($0)" }.joined(separator: "/")
        return "\(box.method.string) /\(path)"
    }
    
    let sendableBox: NIOLockedValueBox<SendableBox>
    
    public init(
        method: HTTPMethod,
        path: [PathComponent],
        responder: Responder,
        requestType: Any.Type,
        responseType: Any.Type
    ) {
        self.requestType = requestType
        self.responseType = responseType
        self.userInfo = [:]
        let box = SendableBox(method: method, path: path, responder: responder)
        self.sendableBox = .init(box)
    }
       
    @discardableResult
    public func description(_ string: String) -> Route {
        self.userInfo["description"] = string
        return self
    }
}
