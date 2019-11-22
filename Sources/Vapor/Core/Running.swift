public struct Running {
    public static func start(using promise: EventLoopPromise<Void>) -> Running {
        return self.init(promise: promise)
    }
    
    public var onStop: EventLoopFuture<Void> {
        return self.promise.futureResult
    }

    private let promise: EventLoopPromise<Void>

    public func stop() {
        self.promise.succeed(())
    }
}

final class RunningService {
    var current: Running?
    init() { }
}
