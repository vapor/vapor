/// A notification is any type that emits
public protocol NotificationEmitter {
    associatedtype Notification
    
    func handleNotification(callback: @escaping NotificationCallback)
}

extension NotificationEmitter {
    /// Callback for accepting a result.
    public typealias NotificationCallback = ((Notification) -> ())
}
