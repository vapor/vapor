#if !os(Linux)

    import Foundation

    /*
     Temporarily not available on Linux until Foundation's 'Dispatch apis are available
     */

    public enum PromiseError: ErrorProtocol {
        case promiseNotCalled
        case timedOut
    }

    /*:
        This class is designed to make it possible to use asynchronous contexts in a synchronous environment.
    */
    public final class Promise<T> {
        private var result: Result<T>? = .none
        private let semaphore: DispatchSemaphore
        private let lock = Lock()

        private init(_ semaphore: DispatchSemaphore) {
            self.semaphore = semaphore
        }

        /*:
            Resolve the promise with a successful result
        */
        public func resolve(with value: T) {
            lock.locked {
                // TODO: Fatal error or throw? It's REALLY convenient NOT to throw here. Should at least log warning
                guard result == nil else { return }
                result = .success(value)
                semaphore.signal()
            }
        }

        /*:
            Reject the promise with an appropriate error
        */
        public func reject(with error: ErrorProtocol) {
            lock.locked {
                guard result == nil else { return }
                result = .failure(error)
                semaphore.signal()
            }
        }
    }

    extension Promise {
        /*:
            This function is used to enter an asynchronous supported context with a promise
            object that can be used to complete a given operation.
         
                let value = try Promise<Int>.async { promise in 
                    // .. do whatever necessary passing around `promise` object
                    // eventually call
                    
                    promise.resolve(with: 42)
                    
                    // or
         
                    promise.resolve(with: errorSignifyingFailure)
                }
         
            - warning: Calling a `promise` multiple times will have no effect.
        */
        public static func async(timingOut timeout: DispatchTime = .distantFuture,
                                 _ handler: (Promise) throws -> Void) throws -> T {
            let semaphore = DispatchSemaphore(value: 0)
            let sender = Promise<T>(semaphore)
            // Ok to call synchronously, since will still unblock semaphore
            // TODO: Find a way to enforce sender is called, not calling will perpetually block w/ long timeout
            try handler(sender)
            let semaphoreResult = semaphore.wait(timeout: timeout)
            switch semaphoreResult {
            case .Success:
                guard let result = sender.result else { throw PromiseError.promiseNotCalled }
                return try result.extract()
            case .TimedOut:
                throw PromiseError.timedOut
            }
        }
    }
#endif
