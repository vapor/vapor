/// A promise timed out
public struct PromiseTimeout<E>: Swift.Error {
    public let expected: E.Type
    
    init(expecting: E.Type) {
        self.expected = expecting
    }
}
