
public final class Subscription {
    private var completion: Void -> Void = {}
    deinit {
        completion()
    }
}

public final class Event<T> {
    public typealias Handler = T -> Void
    private typealias Subscriber = (token: Subscription, handler: Handler)
    private var subscribers: [Subscriber] = []

    @warn_unused_result(message: "subscription must be retained to receive events")
    public func subscribe(handler: Handler) -> Subscription {
        let newToken = Subscription()
        subscribers.append((newToken, handler))
        newToken.completion = { [weak self] in
            guard let welf = self else { return }
            welf.subscribers = welf.subscribers.filter { token, _ in
                return token !== newToken
            }
        }
        return newToken
    }

    public func post(data: T) {
        subscribers.forEach { _, handler in handler(data) }
    }
}
