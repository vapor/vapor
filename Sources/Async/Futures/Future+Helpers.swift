extension Future {
    /// Reduces a nested future into a one-dimensional future, preventing code pyramids
    public func reduce<B>(_ closure: @escaping ((T) throws -> (B))) -> Future<B> {
        let promise = Promise<B>()
        
        self.then { result in
            do {
                promise.complete(try closure(result))
            } catch {
                promise.fail(error)
            }
        }.catch { error in
            promise.fail(error)
        }
        
        return promise.future
    }
}
