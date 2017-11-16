extension Promise {
    /// Flattens a future's completions and failures into this promise with the same expectations
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/async/futures-basics/#flat-mapping-results)
    public func flatten(_ future: Future<T>) {
        future.do(complete).catch(fail)
    }
}

extension FutureType where Expectation == Self {
    public func addAwaiter(callback: @escaping ((FutureResult<Self>) -> ())) {
        callback(.expectation(self))
    }
}
