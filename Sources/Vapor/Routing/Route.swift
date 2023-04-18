import NIOHTTP1
import RoutingKit
import NIOConcurrencyHelpers

// This needs to be unchecked because of the use of `Any` throughout which means we can't use
// helpers like NIOLockedValueBox
public final class Route: CustomStringConvertible, @unchecked Sendable {
    public var method: HTTPMethod {
        get {
            self.concurrencyLock.withLock {
                _method
            }
        }
        set {
            self.concurrencyLock.withLockVoid {
                _method = newValue
            }
        }
    }
    public var path: [PathComponent] {
        get {
            self.concurrencyLock.withLock {
                _path
            }
        }
        set {
            self.concurrencyLock.withLockVoid {
                _path = newValue
            }
        }
    }
    public var responder: Responder {
        get {
            self.concurrencyLock.withLock {
                return _responder
            }
        }
        set {
            self.concurrencyLock.withLockVoid {
                _responder = newValue
            }
        }
    }
    public var requestType: Any.Type {
        get {
            self.concurrencyLock.withLock {
                return _requestType
            }
        }
        set {
            self.concurrencyLock.withLockVoid {
                _requestType = newValue
            }
        }
    }
    public var responseType: Any.Type {
        get {
            self.concurrencyLock.withLock {
                return _responseType
            }
        }
        set {
            self.concurrencyLock.withLockVoid {
                _responseType = newValue
            }
        }
    }
    public var userInfo: [AnyHashable: Any] {
        get {
            self.concurrencyLock.withLock {
                return _userInfo
            }
        }
        set {
            self.concurrencyLock.withLockVoid {
                _userInfo = newValue
            }
        }
    }
    
    private let concurrencyLock: NIOLock
    private var _path: [PathComponent]
    private var _method: HTTPMethod
    private var _responder: Responder
    private var _requestType: Any.Type
    private var _responseType: Any.Type
    private var _userInfo: [AnyHashable: Any]

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
        self.concurrencyLock = .init()
        self._method = method
        self._path = path
        self._responder = responder
        self._requestType = requestType
        self._responseType = responseType
        self._userInfo = [:]
    }
       
    @discardableResult
    public func description(_ string: String) -> Route {
        self.userInfo["description"] = string
        return self
    }
}
