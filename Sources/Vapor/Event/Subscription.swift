/**
    This class is used to keep a subscription to an event active.

    Set all references to `nil` to no longer receive events
 */
public final class Subscription {
    /**
        Completion to run on deinit.

        - Warning: This should only be used by an event to clear subscription on deinitialization
     */
    internal var completion: (Void) -> Void = {}
    deinit {
        completion()
    }
}
