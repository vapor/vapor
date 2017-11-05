import Foundation
import Dispatch

/// A future is an entity that stands inbetween the provider and receiver.
///
/// A provider returns a future type that will be completed with the future result
///
/// A future can also contain an error, rather than a result.
///
/// http://localhost:8000/async/promise-future-introduction/
public final class Future<T>: FutureType {
    public typealias Notification = FutureResult<T>
    
    /// Future expectation type
    public typealias Expectation = T

    /// The future's result will be stored
    /// here when it is resolved.
    private var result: Notification?

    /// A list of all handlers waiting to 
    private var awaiters: [NotificationCallback]

    /// Creates a new, uncompleted, unprovoked future
    /// Can only be created by a Promise, so this is hidden
    internal init() {
        awaiters = []
        awaiters.reserveCapacity(5)
        result = nil
    }

    /// Pre-filled promise future
    ///
    /// http://localhost:8000/async/promise-future-introduction/#futures-without-promise
    public convenience init(_ result: T) {
        self.init()
        self.result = .expectation(result)
    }

    /// Pre-filled failed promise
    ///
    /// http://localhost:8000/async/promise-future-introduction/#futures-without-promise
    public convenience init(error: Error) {
        self.init()
        self.result = .error(error)
    }
    
    /// `true` if the future is already completed.
    public var isCompleted: Bool {
        return result != nil
    }

    /// Completes the result, notifying awaiters.
    internal func complete(with result: Notification) {
        guard self.result == nil else {
            return
        }
        
        self.result = result

        for awaiter in self.awaiters {
            awaiter(result)
        }
    }
    
    /// Locked method for adding an awaiter
    ///
    /// http://localhost:8000/async/advanced-futures/#adding-awaiters-to-all-results
    public func handleNotification(callback: @escaping NotificationCallback) {
        if let result = self.result {
            callback(result)
        } else {
            self.awaiters.append(callback)
        }
    }
}
