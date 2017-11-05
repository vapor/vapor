/// A type of notification that can emit notifications more than once and doesn't emit errors
///
/// Notifications are not stored and you will not get previous notifications
public final class SingleNotification<T>: NotificationEmitter {
    public typealias Result = T
    
    var awaiters = [NotificationCallback]()
    var notified = false
    
    public init() {
        awaiters.reserveCapacity(5)
    }
    
    public func handleNotification(callback: @escaping ((T) -> ())) {
        awaiters.append(callback)
    }
    
    public func notify(of notification: T) {
        guard !notified else { return }
        
        for awaiter in awaiters {
            awaiter(notification)
        }
        
        notified = true
    }
}

extension SingleNotification where T == Void {
    public func notify() {
        self.notify(of: ())
    }
}
