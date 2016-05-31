extension Subscription {
    /**
        This is used to contain subscriptions w/o reference
        it is necessary for the reference management to work

        It should only be used internally.
     */
    private struct Holder {
        /// The subscription that should be contained
        weak var subscription: Subscription?
    }
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
    public typealias Handler = (T) -> Void

    /// A subscriber tuple
    private typealias Subscriber = (token: Subscription.Holder, handler: Handler)

    /// The current subscribers for this event
    private var subscribers: [Subscriber] = []

    @warn_unused_result(message: "subscription must be retained to receive events")
    /**
        Adds a subscriber for this event with a handler to fire on post.

        - parameter handler: the closure to fire when event data is posted

        - Warning: subscription returned from this function must be retained to receive events

        - returns: a subscription. As long as it's retained, the passed handler will fire
     */
    public func subscribe(_ handler: Handler) -> Subscription {
        let newSubscription = Subscription()
        newSubscription.completion = { [weak self, weak newSubscription] in
            guard let welf = self else { return }
            welf.subscribers = welf.subscribers.filter { holder, _ in
                return holder.subscription !== newSubscription
            }
        }

        let holder = Subscription.Holder(subscription: newSubscription)
        subscribers.append((holder, handler))

        return newSubscription
    }

    /**
        Post an event to all subscribers.

        - parameter data: the data to be passed to subscribers
     */
    public func post(_ data: T) {
        subscribers.forEach { _, handler in handler(data) }
    }
}
