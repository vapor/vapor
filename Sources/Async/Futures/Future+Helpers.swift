extension Future {
    /// Reduces a nested future into a one-dimensional future, preventing code pyramids
    public func reduce<B>(_ closure: @escaping ((T) throws -> (Future<B>))) -> Future<B> {
        let promise = Promise<B>()
        
        self.then { result in
            do {
                try closure(result).then { result in
                    promise.complete(result)
                    
                // Cascades failed promise results
                }.catch { error in
                    promise.fail(error)
                }
            // Failed transformations fail the promise
            } catch {
                promise.fail(error)
            }
        // Cascades failed promises
        }.catch { error in
            promise.fail(error)
        }
        
        return promise.future
    }
}
