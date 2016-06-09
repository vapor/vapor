/**
 This class is intended to make interacting with and iterating through
 a static data buffer a simpler process.
 
 It's intent is to be subclassed so the next function can be overridden with further rules
 */
public class StaticDataBuffer {
    private var localBuffer: [Byte] = []
    private var buffer: IndexingIterator<[Byte]>

    public convenience init(data: Data) {
        self.init(bytes: data.bytes)
    }

    public init(bytes: [Byte]) {
        self.buffer = bytes.makeIterator()
    }

    // MARK: Next

    public func next() throws -> Byte? {
        /*
         local buffer is used to maintain last bytes while still interacting w/ byte buffer
         */
        guard localBuffer.isEmpty else {
            return localBuffer.removeFirst()
        }
        return buffer.next()
    }

    // MARK: Discard Extranneous Tokens

    public func discardNext(_ count: Int) throws {
        _ = try collect(next: count)
    }

    // MARK: Check Tokens

    public func checkLeadingBuffer(matches: Byte...) throws -> Bool {
        return try checkLeadingBuffer(matches: matches)
    }

    public func checkLeadingBuffer(matches: [Byte]) throws -> Bool {
        let leading = try collect(next: matches.count)
        localBuffer.append(contentsOf: leading)
        return leading == matches
    }

    // MARK: Collection

    public func collect(next count: Int) throws -> [Byte] {
        guard count > 0 else { return [] }

        var body: [Byte] = []
        try (1...count).forEach { _ in
            guard let next = try next() else { return }
            body.append(next)
        }
        return body
    }

    /*
     When in Query segment, `+` should be interpreted as ` ` (space), not sure useful outside of that point
     */
    public func collect(until delimitters: Byte..., convertIfNecessary: (Byte) -> Byte = { $0 }) throws -> [Byte] {
        var collected: [Byte] = []
        while let next = try next() {
            if delimitters.contains(next) {
                // If the delimitter is also a token that identifies
                // a particular section of the URI
                // then we may want to return that byte to the buffer
                localBuffer.append(next)
                break
            }

            let converted = convertIfNecessary(next)
            collected.append(converted)
        }
        return collected
    }

    public func collectRemaining() throws -> [Byte] {
        var complete: [Byte] = []
        while let next = try next() {
            complete.append(next)
        }
        return complete
    }

}
