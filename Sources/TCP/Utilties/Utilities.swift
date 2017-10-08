/// Infinitely loop over a collection.
/// Used to supply server worker queues to clients.
internal struct LoopIterator<Base: Collection>: IteratorProtocol {
    private let collection: Base
    private var index: Base.Index

    /// Create a new Loop Iterator from a collection.
    init(collection: Base) {
        self.collection = collection
        self.index = collection.startIndex
    }

    /// Get the next item in the loop iterator.
    mutating func next() -> Base.Iterator.Element? {
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

public enum CurrentHost {
    public static var hostname: String {
        #if os(Linux)
            return ProcessInfo().hostName
        #else
            return "localhost"
        #endif
    }
}

#if os(Linux)
import libc

// fix some constants on linux
let SOCK_STREAM = Int32(libc.SOCK_STREAM.rawValue)
let IPPROTO_TCP = Int32(libc.IPPROTO_TCP)
#endif
