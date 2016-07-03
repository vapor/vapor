#if !os(Linux)

    import Foundation

    /*
     Temporarily not available on Linux until Foundation's 'Dispatch apis are available
     */

    public enum PromiseError: ErrorProtocol {
        case promiseNotCalled
        case timedOut
    }

    // TODO: Is Promise the right word here?

    public final class Promise<T> {
        private var result: Result<T>? = .none
        private let semaphore: DispatchSemaphore

        private init(_ semaphore: DispatchSemaphore) {
            self.semaphore = semaphore
        }

        public func send(_ value: T) {
            // TODO: Fatal error or throw? It's REALLY convenient NOT to throw here. Should at least log warning
            guard result == nil else { return }
            result = .success(value)
            semaphore.signal()
        }

        public func send(_ error: ErrorProtocol) {
            guard result == nil else { return }
            result = .failure(error)
            semaphore.signal()
        }
    }

    extension Promise {
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

    extension Response {
        public static func async(timingOut timeout: DispatchTime = .distantFuture, _ handler: (Promise<ResponseRepresentable>) throws -> Void) throws -> ResponseRepresentable {
            return try Promise.async(timingOut: timeout, handler)
        }
    }

#endif
