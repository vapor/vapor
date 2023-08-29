import NIOCore
import NIOConcurrencyHelpers

extension Application {
    public struct Running: Sendable {
        final class Storage: Sendable {
            let current: NIOLockedValueBox<Running?>
            init() {
                self.current = .init(nil)
            }
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
