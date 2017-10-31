extension Promise {
    /// Flattens a future's completions and failures into this promise with the same expectations
    public func flatten(_ future: Future<T>) {
        future.then(complete).catch(fail)
    }
}

extension FutureType where Expectation == Self {
    public func addAwaiter(callback: @escaping ((FutureResult<Self>) -> ())) {
        callback(.expectation(self))
    }
}
