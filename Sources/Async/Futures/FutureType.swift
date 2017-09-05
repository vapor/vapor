import Foundation
import Dispatch

/// A future result type.
/// Concretely implemented by `Future<T>`
public protocol FutureType {
    associatedtype Expectation
    func addAwaiter(callback: @escaping ResultCallback)
}

// MARK: Convenience

extension FutureType {
    /// This future's result type.
    public typealias Result = FutureResult<Expectation>

    /// Callback for accepting a result.
    public typealias ResultCallback = ((Result) -> ())

    /// Callback for accepting the expectation.
    public typealias ExpectationCallback = ((Expectation) -> ())

    /// Callback for accepting an error.
    public typealias ErrorCallback = ((Error) -> ())

    /// Callback for accepting the expectation.
    public typealias ExpectationMapCallback<T> = ((Expectation) throws -> (T))

    /// Adds a handler to be asynchronously executed on
    /// completion of this future.
    ///
    /// Will *not* be executed if an error occurrs
    public func then(callback: @escaping ExpectationCallback) -> Self {
        addAwaiter { result in
            guard let ex = result.expectation else {
                return
            }

            callback(ex)
        }
        
        return self
    }

    /// Adds a handler to be asynchronously executed on
    /// completion of this future.
    ///
    /// Will *only* be executed if an error occurred.
    //// Successful results will not call this handler.
    public func `catch`(callback: @escaping ErrorCallback) {
        addAwaiter { result in
            guard let er = result.error else {
                return
            }

            callback(er)
        }
    }

    /// Maps a future to a future of a different type.
    public func map<T>(callback: @escaping ExpectationMapCallback<T>) -> Future<T> {
        let promise = Promise(T.self)

        then { expectation in
            do {
                let mapped = try callback(expectation)
                promise.complete(mapped)
            } catch {
                promise.fail(error)
            }
        }.catch { error in
            promise.fail(error)
        }

        return promise.future
    }

    /// Waits until the specified time for a result.
    ///
    /// Will return the results when available unless the specified
    /// time has been reached, in which case it will timeout
    public func sync(deadline time: DispatchTime = .distantFuture) throws -> Expectation {
        let semaphore = DispatchSemaphore(value: 0)
        var awaitedResult: FutureResult<Expectation>?

        addAwaiter { result in
            awaitedResult = result
            semaphore.signal()
        }

        guard semaphore.wait(timeout: time) == .success else {
            throw PromiseError(identifier: "timeout", reason: "Timeout reached waiting for future \(Expectation.self)")
        }

        return try awaitedResult!.unwrap()
    }

    /// Waits for the specified duration for a result.
    ///
    /// Will return the results when available unless the specified timeout has been reached, in which case it will timeout
    public func sync(timeout interval: DispatchTimeInterval) throws -> Expectation {
        return try sync(deadline: DispatchTime.now() + interval)
    }
}

// MARK: Array


extension Array where Element: FutureType {
    /// Flattens an array of future results into one
    /// future array result.
    public func flatten() -> Future<[Element.Expectation]> {
        let promise = Promise<[Element.Expectation]>()

        var elements: [Element.Expectation] = []

        var iterator = makeIterator()
        func handle(_ future: Element) {
            future.then { res in
                elements.append(res)
                if let next = iterator.next() {
                    handle(next)
                } else {
                    promise.complete(elements)
                }
            }.catch { error in
                promise.fail(error)
            }
        }

        if let first = iterator.next() {
            handle(first)
        } else {
            promise.complete(elements)
        }

        return promise.future
    }
}
