extension Promise {
    /// Flattens a future's completions and failures into this promise with the same expectations
    ///
    /// http://localhost:8000/async/futures-basics/#flat-mapping-results
    public func flatten(_ future: Future<T>) {
        future.then(callback: self.complete).catch(callback: self.fail)
    }
}

extension FutureType where Expectation == Self {
    public func addAwaiter(callback: @escaping ((FutureResult<Self>) -> ())) {
        callback(.expectation(self))
    }
}
