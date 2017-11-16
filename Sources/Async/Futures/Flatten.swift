/// A closure that returns a future.
public typealias LazyFuture<T> = () -> (Future<T>)

/// FIXME: some way to make this generic?
extension Array where Element == LazyFuture<Void> {
    /// Flattens an array of lazy futures into a future with an array of results.
    /// note: each subsequent future will wait for the previous to
    /// complete before starting.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/async/advanced-futures/#combining-multiple-futures)
    public func syncFlatten() -> Future<Void> {
        let promise = Promise<Void>()

        var iterator = makeIterator()
        func handle(_ future: Element) {
            future().do { res in
                if let next = iterator.next() {
                    handle(next)
                } else {
                    promise.complete()
                }
            }.catch { error in
                promise.fail(error)
            }
        }

        if let first = iterator.next() {
            handle(first)
        } else {
            promise.complete()
        }

        return promise.future
    }
}

extension Array where Element: FutureType {
    /// Flattens an array of futures into a future with an array of results.
    /// note: the order of the results will match the order of the
    /// futures in the input array.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/async/advanced-futures/#combining-multiple-futures)
    public func orderedFlatten() -> Future<[Element.Expectation]> {
        let promise = Promise<[Element.Expectation]>()

        var elements: [Element.Expectation] = []
        elements.reserveCapacity(self.count)

        var iterator = makeIterator()
        func handle(_ future: Element) {
            future.do { res in
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


extension Array where Element: FutureType {
    /// See FutureType.map
    public func map<T>(_ callback: @escaping ([Element.Expectation]) throws -> T) -> Future<T> {
        return flatten().map(callback)
    }

    /// See FutureType.then
    public func then<T>(_ callback: @escaping ([Element.Expectation]) throws -> Future<T>) -> Future<T> {
        return flatten().then(callback)
    }

    /// Flattens an array of futures into a future with an array of results.
    /// note: the results will be in random order.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/async/advanced-futures/#combining-multiple-futures)
    public func flatten() -> Future<[Element.Expectation]> {
        let many = ManyFutures(self)
        return many.promise.future
    }
}


extension Array where Element: FutureType, Element.Expectation == Void {
    /// See FutureType.map
    public func map<T>(_ callback: @escaping () throws -> T) -> Future<T> {
        return flatten().map { _ in
            return try callback()
        }
    }

    /// See FutureType.then
    public func then<T>(_ callback: @escaping () throws -> Future<T>) -> Future<T> {
        return flatten().then { _ in
            return try callback()
        }
    }

    /// Flattens an array of void futures into a single one.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/async/advanced-futures/#combining-multiple-futures)
    public func flatten() -> Future<Void> {
        let many = ManyFutures(self)
        let promise = Promise(Void.self)
        many.promise.future.do { _ in
            promise.complete()
        }.catch(promise.fail)
        return promise.future
    }
}

/// Internal class for representing more than one future.
internal final class ManyFutures<F: FutureType> {
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
            future.do { res in
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
