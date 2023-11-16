import NIOHTTP1
import RoutingKit
import NIOConcurrencyHelpers

public struct SendableRoute: CustomStringConvertible, Sendable {
    public var method: HTTPMethod
    public var path: [PathComponent]
    public var responder: Responder
    public var requestType: Any.Type
    public var responseType: Any.Type
    public let userInfo: UserDictionary
    
    // Reference type dictionary to allow us to keep an immutable `Route` struct but
    // mutate the dictionary without any copies which breaks how Vapor's routing works
    public final class UserDictionary: Sendable {
        let dictionary: NIOLockedValueBox<[String: Sendable]>
        
        init() {
            self.dictionary = .init([:])
        }
        
        public subscript(_ key: String) -> Sendable? {
            get { 
                return self.dictionary.withLockedValue { $0[key] }
            }
            set(newValue) { 
                self.dictionary.withLockedValue { $0[key] = newValue }
            }
        }
    }

    public var description: String {
        let path = self.path.map { "\($0)" }.joined(separator: "/")
        return "\(self.method.string) /\(path)"
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
        self.userInfo = .init()
    }
       
    @discardableResult
    public func description(_ string: String) -> SendableRoute {
        self.userInfo["description"] = string
        return self
    }
}
