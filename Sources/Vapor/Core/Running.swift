extension Application {
    public struct Running {
        final class Storage {
            var current: Running?
            init() { }
        }

        public static func start(using promise: EventLoopPromise<Void>) -> Self {
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
}
