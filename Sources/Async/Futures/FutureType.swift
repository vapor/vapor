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

    /// Callback for accepting the expectation.
    public typealias ExpectationMapCallback<T> = (Expectation) throws -> (T)

    /// Adds a handler to be asynchronously executed on
    /// completion of this future.
    ///
    /// Will *not* be executed if an error occurrs
    public func then(_ callback: @escaping ExpectationCallback) -> Self {
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
    public func `catch`(_ callback: @escaping ErrorCallback) {
        addAwaiter { result in
            guard let er = result.error else {
                return
            }

            callback(er)
        }
    }

    /// Maps a future to a future of a different type.
    public func map<T>(_ callback: @escaping ExpectationMapCallback<T>) -> Future<T> {
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
        then(promise.complete).catch(promise.fail)
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
    public func blockingAwait(timeout interval: DispatchTimeInterval) throws -> Expectation {
        return try blockingAwait(deadline: DispatchTime.now() + interval)
    }
}

// MARK: Array


//extension Array where Element: FutureType {
//    /// Flattens an array of future results into one
//    /// future array result.
//    public func flatten() -> Future<[Element.Expectation]> {
//        let promise = Promise<[Element.Expectation]>()
//
//        var elements: [Element.Expectation] = []
//
//        var iterator = makeIterator()
//        func handle(_ future: Element) {
//            future.then { res in
//                elements.append(res)
//                if let next = iterator.next() {
//                    handle(next)
//                } else {
//                    promise.complete(elements)
//                }
//            }.catch { error in
//                promise.fail(error)
//            }
//        }
//
//        if let first = iterator.next() {
//            handle(first)
//        } else {
//            promise.complete(elements)
//        }
//
//        return promise.future
//    }
//}

extension Array where Element: FutureType {
    public func flatten() -> Future<[Element.Expectation]> {
        let many = ManyFutures(self)
        return many.promise.future
    }
}


extension Array where Element: FutureType, Element.Expectation == Void {
    public func flatten() -> Future<Void> {
        let many = ManyFutures(self)
        let promise = Promise(Void.self)
        many.promise.future.then { _ in
            promise.complete()
            }.catch(promise.fail)
        return promise.future
    }
}

final class ManyFutures<F: FutureType> {
    /// The future's result will be stored
    /// here when it is resolved.
    var promise: Promise<[F.Expectation]>

    /// The futures completed.
    private var results: [F.Expectation]

    /// Ther errors caught.
    private var errors: [Swift.Error]

    /// All the awaited futures
    private var many: [F]

    /// Create a new many future.
    public init(_ many: [F]) {
        self.many = many
        self.results = []
        self.errors = []
        self.promise = Promise<[F.Expectation]>()

        for future in many {
            future.then { res in
                self.results.append(res)
                self.update()
                }.catch { err in
                    self.errors.append(err)
                    self.update()
            }
        }
    }

    /// Updates the many futures
    func update() {
        if results.count + errors.count == many.count {
            if errors.count == 0 {
                promise.complete(results)
            } else {
                promise.fail(errors.first!) // FIXME: combine errors
            }
        }
    }
}
