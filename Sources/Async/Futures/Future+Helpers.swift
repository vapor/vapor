extension Future {
    /// Reduces a nested future into a one-dimensional future, preventing code pyramids
    public func reduce<B>(_ closure: @escaping ((T) throws -> (Future<B>))) -> Future<B> {
        let promise = Promise<B>()
        
        self.then { result in
            do {
                try closure(result).then { result in
                    promise.complete(result)
                }.catch { error in
                    promise.fail(error)
                }
            } catch {
                promise.fail(error)
            }
        }.catch { error in
            promise.fail(error)
        }
        
        return promise.future
    }
}
