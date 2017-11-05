import Async
import HTTP

/// Makes `Response` a drop-in replacement for `Future<Response>
extension Response: FutureType {
    public typealias Notification = FutureResult<Response>
    public typealias Expectation = Response
    
    public func handleNotification(callback: @escaping NotificationCallback) {
        callback(.expectation(self))
    }
}

