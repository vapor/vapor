import NIOHTTP1
import RoutingKit
import NIOConcurrencyHelpers
import ConsoleKit
import HTTPTypes

public final class Route: CustomStringConvertible, Sendable {
    public var method: HTTPRequest.Method {
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
    
    public var requestType: Any.Type {
        get {
            self.sendableBox.withLockedValue { $0.requestType }
        }
        set {
            self.sendableBox.withLockedValue { $0.requestType = newValue }
        }
    }
    
    public var responseType: Any.Type {
        get {
            self.sendableBox.withLockedValue { $0.responseType }
        }
        set {
            self.sendableBox.withLockedValue { $0.responseType = newValue }
        }
    }
    
    struct SendableBox: Sendable {
        var method: HTTPRequest.Method
        var path: [PathComponent]
        var responder: Responder
        var requestType: Any.Type
        var responseType: Any.Type
        var userInfo: [AnySendableHashable: Sendable]
    }
    
    public var userInfo: [AnySendableHashable: Sendable] {
        get {
            self.sendableBox.withLockedValue { $0.userInfo }
        }
        set {
            self.sendableBox.withLockedValue { $0.userInfo = newValue }
        }
    }

    public var description: String {
        let box = self.sendableBox.withLockedValue { $0 }
        let path = box.path.map { "\($0)" }.joined(separator: "/")
        return "\(box.method.rawValue) /\(path)"
    }
    
    let sendableBox: NIOLockedValueBox<SendableBox>
    
    public init(
        method: HTTPRequest.Method,
        path: [PathComponent],
        responder: Responder,
        requestType: Any.Type,
        responseType: Any.Type
    ) {
        let box = SendableBox(
            method: method,
            path: path,
            responder: responder,
            requestType: requestType,
            responseType: responseType,
            userInfo: [:])
        self.sendableBox = .init(box)
    }
       
    @discardableResult
    public func description(_ string: String) -> Route {
        self.userInfo["description"] = string
        return self
    }
}
