/// Infinitely loop over a collection.
/// Used to supply server worker queues to clients.
public struct LoopIterator<Base: Collection>: IteratorProtocol {
    private let collection: Base
    private var index: Base.Index

    /// Create a new Loop Iterator from a collection.
    public init(collection: Base) {
        self.collection = collection
        self.index = collection.startIndex
    }

    /// Get the next item in the loop iterator.
    public mutating func next() -> Base.Iterator.Element? {
        guard !collection.isEmpty else {
            return nil
        }

        let result = collection[index]
        collection.formIndex(after: &index) // (*) See discussion below
        if index == collection.endIndex {
            index = collection.startIndex
        }
        return result
    }
}
