/// Infinitely loop over a collection.
/// Used to supply server worker queues to clients.
public struct LoopIterator<Base>
    where Base: Collection
{
    private let collection: Base
    private var index: Base.Index

    /// Create a new Loop Iterator from a collection.
    public init(_ collection: Base) throws {
        guard !collection.isEmpty else {
            throw CoreError(identifier: "loopIteratorCount", reason: "Collection must have at least one element")
        }
        self.collection = collection
        self.index = collection.startIndex
    }

    /// Get the next item in the loop iterator.
    public mutating func next() -> Base.Iterator.Element {
        let result = collection[index]
        collection.formIndex(after: &index)
        if index == collection.endIndex {
            index = collection.startIndex
        }
        return result
    }
}
