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
    public typealias ResultCallback = (Result) -> ()

    /// Callback for accepting a result.
    public typealias AlwaysCallback = () -> ()

    /// Callback for accepting the expectation.
    public typealias ExpectationCallback = (Expectation) -> ()

    /// Callback for accepting an error.
    public typealias ErrorCallback = (Error) -> ()

    /// Callback for accepting the expectation and returning something else.
    public typealias ExpectationMapCallback<T> = (Expectation) throws -> T

    /// Callback for accepting the expectation and returning a new future.
    public typealias ExpectationThenCallback<T> = (Expectation) throws -> Future<T>

    /// Adds a handler to be asynchronously executed on
    /// completion of this future.
    ///
    /// Will *not* be executed if an error occurrs
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/async/promise-future-introduction/#on-future-completion)
    public func `do`(_ callback: @escaping ExpectationCallback) -> Self {
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
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/async/promise-future-introduction/#on-future-completion)
    public func `catch`(_ callback: @escaping ErrorCallback) {
        addAwaiter { result in
            guard let er = result.error else {
                return
            }

            callback(er)
        }
    }

    /// Maps a future to a future of a different type.
    /// The result returned within should be non-future type.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/async/promise-future-introduction/#mapping-results)
    public func map<T>(to type: T.Type = T.self, _ callback: @escaping ExpectationMapCallback<T>) -> Future<T> {
        let promise = Promise(T.self)

        self.do { expectation in
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

    /// Maps a future to a future of a different type.
    /// The result returned within should be a future.
    public func then<T>(_ callback: @escaping ExpectationThenCallback<T>) -> Future<T> {
        let promise = Promise(T.self)

        self.do { expectation in
            do {
                let mapped = try callback(expectation)
                mapped.chain(to: promise)
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
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/async/promise-future-introduction/#synchronous-apis)
    public func blockingAwait(deadline time: DispatchTime = .distantFuture) throws -> Expectation {
        let semaphore = DispatchSemaphore(value: 0)
        var awaitedResult: FutureResult<Expectation>?

        addAwaiter { result in
            awaitedResult = result
            semaphore.signal()
        }

        guard semaphore.wait(timeout: time) == .success else {
            throw PromiseTimeout(expecting: Expectation.self)
        }

        return try awaitedResult!.unwrap()
    }

    /// Chains a future to a promise of the same type.
    public func chain(to promise: Promise<Expectation>) {
        self.do(promise.complete).catch(promise.fail)
    }

    /// Get called back whenever the future is complete,
    /// ignoring the result.
    public func always(_ callback: @escaping AlwaysCallback) {
        addAwaiter { _ in
            callback()
        }
    }

    /// Waits for the specified duration for a result.
    ///
    /// Will return the results when available unless the specified timeout has been reached, in which case it will timeout
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/async/promise-future-introduction/#synchronous-apis)
    public func blockingAwait(timeout interval: DispatchTimeInterval) throws -> Expectation {
        return try blockingAwait(deadline: DispatchTime.now() + interval)
    }
}

/// Globally available `then` for mimicking behavior of calling `return future.then`
/// where no starting future is available.
///
/// This allows you to convert any non-throwing, future-return method into a
/// closure that accepts throwing and returns a future.
public func then<T>(_ callback: @escaping () throws -> Future<T>) -> Future<T> {
    let promise = Promise(T.self)

    do {
        try callback().chain(to: promise)
    } catch {
        promise.fail(error)
    }

    return promise.future
}
