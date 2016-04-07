/**
 This class is used to keep a subscription to an event active.
 
 Set all references to `nil` to no longer receive events
 */
public final class Subscription {
    
    /**
     Completiont to run on deinit.
     
     - Warning: This should only be used by an event to clear the subscription on deinitialization
     */
    private var completion: Void -> Void = {}
    deinit {
        completion()
    }
}

private struct SubscriptionHolder {
    weak var subscription: Subscription?
}

/**
 This class can be used to create event hubs where data
 can be posted to multiple subscribers.
 
 First create a global event hub or associate it with
 a specific class
 
     let BatteryEvent = Event<BatteryLevel>()
 
 Then, subscribe to that event
 
     // Must retain subscription to keep receiving events!
     self.subscription = BatteryEvent.subscribe { level in
         print("Battery level is now: \(level)
     }
 
 Whenever someone has access to the event, they can post data to it like so:
 
     BatteryEvent.post(80)
 */
public final class Event<T> {
    
    
    /// Closure called when event emits
    public typealias Handler = T -> Void
    
    /// A subscriber tuple
    private typealias Subscriber = (token: SubscriptionHolder, handler: Handler)
    
    /// The current subscribers for this event
    private var subscribers: [Subscriber] = []
    
    /**
     Adds a subscriber for this event with a handler to fire on post.
     
     - Warning: subscription returned from this function must be retained to receive events
     
     - returns: as long as the subscription is retained, the passed handler will fire
     */
    @warn_unused_result(message: "subscription must be retained to receive events")
    public func subscribe(handler: Handler) -> Subscription {
        let newToken = Subscription()
        let holder = SubscriptionHolder(subscription: newToken)
        subscribers.append((holder, handler))
        newToken.completion = { [weak self, weak newToken] in
            guard let welf = self else { return }
            welf.subscribers = welf.subscribers.filter { holder, _ in
                return holder.subscription !== newToken
            }
        }
        return newToken
    }
    
    /**
     Post an event to all subscribers.
     
     - parameter data: the data to be passed to subscribers
     */
    public func post(data: T) {
        subscribers.forEach { _, handler in handler(data) }
    }
}
